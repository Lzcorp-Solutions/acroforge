# File Formats

## Schema format

Schemas are YAML or JSON files in the "rich form":

```yaml
first_name:
  type: string
gender:
  type: select
  options:
    - male
    - female
national_id:
  type: string
  variations:
    - Ghana Card
    - National ID
    - Ecowas Identity Card Number
amount_requested:
  type: money
```

**Field keys** (`first_name`, `gender`, ...) become Ruby symbols. **`type`** is one of `string | select | boolean | money | date | email | number`. **`options`** are the allowed select values (for `select` and `boolean` types).

**`variations`** is *optional*. Include it only when a vendor renders the same logical field under a label that doesn't sanitize to your canonical key — e.g. listing `"Ghana Card"` and `"National ID"` under `:national_id` so the spatial heuristic resolves both to the same key. Per-PDF schemas produced by `schema infer` omit `variations:` when the field name already matches its canonical key.

AcroForge also accepts a legacy "shorthand" form where the value is just an array of variations. `AcroForge::Schema.normalize` upgrades it to rich form on the way in:

```ruby
{
  full_name: ["Full Name", "First Name", "Surname"],
  dob:       ["Date of Birth", "DOB"]
}
```

The shorthand form is convenient when you're constructing schemas in Ruby code and don't need type annotations or select options. Once you pass the hash to `Schema.load`, it is normalised to rich form internally.

## Mapping file format

`relabel propose` writes one of these. Edit the `key:` and `type:` values; the `meta:` blocks are advisory and get regenerated on the next `propose`.

```yaml-vue
_meta:
  source_pdf: broken_form.pdf
  generated_at: 2026-05-26T14:32:11Z
  acroforge_version: {{ $version }}
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
  key: full_name          # collision: apply! renames this one to full_name_1
  type: string
  meta:
    raw_label: Customer Name
    confidence: medium
    section: personal_details
    page: 0

page0_field99:
  key: ~                  # null = skip this field, leave its name unchanged
  type: ~
  meta:
    raw_label: ~
    confidence: none
    section: ~
    page: 3
```

### Editing the mapping file

Only `key` and `type` under each field entry are consumed by `relabel apply`. The `meta` block is regenerated on every `propose` run and exists solely for your reference when reviewing.

Rules:

- `key` must match `/\A[a-z][a-z0-9_]*\z/`. Invalid keys cause `apply!` to raise `RelabelError` *before* writing anything to the PDF.
- Setting `key: ~` (YAML null) tells `apply!` to skip that field entirely. Its internal name is left unchanged.
- Duplicate keys are allowed and expected. `apply!` auto-disambiguates them by appending `_1`, `_2`, etc. in page order.
- The `_meta` block at the top is informational; `apply!` ignores it.
