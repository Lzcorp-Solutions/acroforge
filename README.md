# AcroForge

A Ruby toolkit for working with PDF AcroForms, especially the broken ones.

AcroForge reads, validates, relabels, and fills PDF forms. Its standout feature is the **relabeling workflow**: when a vendor ships you a fillable PDF whose internal field names look like `page0_field6`, `Text101`, or worse, AcroForge runs a spatial heuristic to figure out what each field is _actually_ for, writes its proposal to a human-reviewable YAML file, and then permanently renames the AcroForm fields once you've approved the mapping. The result is a PDF you can fill programmatically without ever again writing `pdf.fields["page0_field6"] = "Alice"`.

It works on any AcroForm PDF: loan applications, school admission forms, government paperwork, internal HR templates. Nothing in the gem is domain-specific.

## Requirements

- Ruby `>= 2.7`
- [HexaPDF](https://hexapdf.gettalong.org/) `~> 1.0` (runtime dependency, installed automatically)

## Installation

Until AcroForge is published to rubygems.org, depend on it via a local path or git URL.

In your `Gemfile`:

```ruby
gem "acroforge", path: "/path/to/acroforge"
# or
gem "acroforge", git: "https://github.com/Lzcorp-Solutions/acroforge.git"
```

Then `bundle install`.

## Quick start: the relabeling workflow

Given a PDF with garbage-named fields:

```bash
# 1. Generate a starter schema (advisory; the heuristic's best guess at canonical keys)
$ acroforge schema infer broken_form.pdf --out schema.yml

# 2. Generate a draft mapping (per-field rename proposals, sorted by page/position)
$ acroforge relabel propose broken_form.pdf --schema schema.yml --out mapping.yml

# 3. Review mapping.yml in your editor: fix wrong proposals, fill in any blanks

# 4. Apply the mapping: permanently renames the AcroForm fields in place
$ acroforge relabel apply broken_form.pdf mapping.yml
```

After step 4, the PDF's internal field names are semantic (`full_name`, `email`, `gender`, ...) and you can fill the form programmatically with confidence.

The shortcut for the first two steps:

```bash
$ acroforge bootstrap broken_form.pdf
# writes schema.yml AND mapping.yml in one pass
```

## CLI

```text
acroforge schema infer <pdf>     [--out schema.yml] [--sections a,b,c]
acroforge relabel propose <pdf>  [--out mapping.yml] [--schema schema.yml] [--merge|--overwrite]
acroforge relabel apply <pdf> <mapping.yml>
acroforge compile <pdf>          [--schema schema.yml]
acroforge bootstrap <pdf>        [--schema-out s.yml] [--mapping-out m.yml]
acroforge version
acroforge help
```

| Subcommand        | What it does                                                                                                                                                                                                   |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `schema infer`    | Runs the heuristic on a PDF and writes a starter schema (canonical key → type + variations). Advisory; you review and edit.                                                                                    |
| `relabel propose` | Writes a YAML mapping file proposing a semantic name for every AcroForm field. Sorted by page → top-to-bottom → left-to-right. Default mode `--merge` preserves any `key`/`type` values you've already edited. |
| `relabel apply`   | Reads a corrected mapping file and rewrites `field[:T]` / `field[:TU]` in the source PDF in place. Auto-disambiguates collisions (`full_name`, `full_name_1`, ...).                                            |
| `compile`         | Diagnostic: runs the engine and prints mapped/unmapped counts. Useful for checking heuristic coverage without writing any files.                                                                               |
| `bootstrap`       | Convenience: `schema infer` + `relabel propose` in one call.                                                                                                                                                   |

Exit codes: `0` success, `1` user error (bad args, missing file), `2` validation error, `3` internal error.

## Library API

```ruby
require "acroforge"

# Compile a PDF and inspect what the heuristic found.
engine = AcroForge::Engine.new(
  "form.pdf",
  schema: AcroForge::Schema.load("schema.yml"),   # or pass a Hash directly
  overrides: {},                                  # optional per-PDF overrides
  sections: ["Personal Details", "Loan Details"]  # optional section headers for scoping
)
result = engine.compile!
# => { mapped: {...}, unmapped: [...], select_options: {...}, new_fields_detected: [...] }

# Fill a form with a payload.
engine.validate_payload!(full_name: "Alice", email: "alice@example.com")
engine.fill!({ full_name: "Alice", email: "alice@example.com" }, "filled.pdf")

# Generate a starter schema from a PDF.
schema = AcroForge::Schema.infer("form.pdf")
AcroForge::Schema.dump(schema, "schema.yml")

# Run the relabeler programmatically.
AcroForge::Relabeler.propose("form.pdf", out: "mapping.yml", schema: schema)
AcroForge::Relabeler.apply!("form.pdf", "mapping.yml")

# Validate individual values.
AcroForge::Validator.valid?("alice@example.com", :email)  # => true
AcroForge::Validator.valid?("not a date", :date)          # => false
```

### Errors

- `AcroForge::ValidationError`: raised by `Engine#validate_payload!` on type mismatch.
- `AcroForge::RelabelError`: raised by `Relabeler.apply!` on malformed mapping YAML, invalid key names, or missing AcroForm.

## Schema format

Schemas are YAML or JSON files in the "rich form":

```yaml
full_name:
  type: string
  variations:
    - Full Name
    - First Name
    - Surname
gender:
  type: select
  variations:
    - Gender
    - Sex
  options:
    - male
    - female
amount_requested:
  type: money
  variations:
    - Amount Requested
    - Loan Amount
```

**Field keys** (`full_name`, `gender`, ...) become Ruby symbols. **`type`** is one of `string | select | boolean | money | date | email | number`. **`variations`** are the human-readable label strings to look for on the page. **`options`** are the allowed select values (for `select` and `boolean` types).

AcroForge also accepts a legacy "shorthand" form where the value is just an array of variations. `AcroForge::Schema.normalize` upgrades it to rich form on the way in:

```ruby
{
  full_name: ["Full Name", "First Name", "Surname"],
  dob:       ["Date of Birth", "DOB"]
}
```

## Mapping file format

`relabel propose` writes one of these. Edit the `key:` and `type:` values; the `meta:` blocks are advisory and get regenerated on the next `propose`.

```yaml
_meta:
  source_pdf: broken_form.pdf
  generated_at: 2026-05-26T14:32:11Z
  acroforge_version: 0.1.0
  total_fields: 98

page0_field6:
  key: full_name
  type: string
  meta:
    raw_label: Full Name
    confidence: high
    section: personal_details
    page: 0

page0_field28:
  key: full_name # collision: apply! renames this one to full_name_1
  type: string
  meta:
    raw_label: Customer Name
    confidence: medium
    section: personal_details
    page: 0

page0_field99:
  key: ~ # null = skip this field, leave its name unchanged
  type: ~
  meta:
    raw_label: ~
    confidence: none
    section: ~
    page: 3
```

`key` must match `/\A[a-z][a-z0-9_]*\z/`. Invalid keys cause `apply!` to raise `RelabelError` _before_ writing anything to the PDF.

## How the heuristic works

For each AcroForm field, AcroForge:

1. Reads every text chunk on the page along with its bounding box.
2. Scores nearby text against the field's widget rectangle using a mode-aware weighted heuristic (Grid-Lock, Inline Paragraph, or Standard Label depending on layout).
3. Picks the best-scoring label, sanitises it into a snake-case key.
4. If a `schema` is supplied, canonicalises the key against its `variations` lists.
5. For radio groups and checkboxes, also discovers the option export values from the widget appearance states.

You can inspect what it found via `engine.field_proposals` after `compile!`. That's the data structure the Relabeler consumes.

## Development

```bash
bundle install
bundle exec rspec        # run the test suite
bundle exec standardrb   # lint
```

Synthetic test fixtures live in `spec/fixtures/`. To regenerate them, run `ruby spec/fixtures/build_fixtures.rb`.

## License

MIT.
