# Library API

## CLI vs Library API

Use the CLI (`acroforge bootstrap`, `acroforge relabel apply`, ...) for one-off tasks, CI pipelines, or shell scripts where you just need to process a PDF and move on.

Use the library API when you need to embed AcroForge inside a Ruby application: for example, to fill forms as part of a loan origination flow, to inspect field proposals programmatically before deciding whether to apply them, or to integrate AcroForge's validation into your own error-handling layer.

All CLI subcommands are thin wrappers around the library API.

## Core classes

### `AcroForge::Engine`

The main entry point. Accepts a PDF path, an optional schema, optional per-PDF overrides, and optional section headers for scoping the heuristic.

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
```

`compile!` returns a hash with four keys:

- `mapped`: PDF field name → canonical key for every field the heuristic resolved
- `unmapped`: list of AcroForm field names that couldn't be matched to a schema key
- `select_options`: discovered export values for radio/checkbox groups
- `new_fields_detected`: schema keys that appear in the PDF but weren't in your schema

After `compile!`, call `engine.field_proposals` to inspect the raw per-field scoring data that the Relabeler consumes. The proposals include `pdf_field_name`, `pdf_field_type`, `canonical_key`, `raw_label` (cleaned), `confidence`, `section`, `page`, `y`, `x`, and `options`.

### `AcroForge::Schema`

Loads, normalises, infers, and dumps schema files.

```ruby
# Generate a starter schema from a PDF.
schema = AcroForge::Schema.infer("form.pdf")
AcroForge::Schema.dump(schema, "schema.yml")

# If you've already compiled an engine, pass it in to avoid a second compile pass.
engine = AcroForge::Engine.new("form.pdf")
engine.compile!
schema = AcroForge::Schema.infer("form.pdf", engine: engine)
```

`Schema.load` accepts a file path (YAML or JSON) and returns a Hash in the rich form (`{key => {type:, variations:, options:}}`). It also normalises shorthand schemas (where values are arrays of variations) into the rich form on the way in.

### `AcroForge::Relabeler`

Runs the propose and apply phases programmatically. Both methods return a result hash describing what happened.

```ruby
# Generate a mapping. Returns { total:, mapped:, unmapped:, out_path: }.
result = AcroForge::Relabeler.propose("form.pdf", out: "mapping.yml", schema: schema)
# => { total: 92, mapped: 82, unmapped: 10, out_path: "mapping.yml" }

# Apply the mapping. Returns { total:, renamed:, disambiguated:, skipped_null:, stale: }.
result = AcroForge::Relabeler.apply!("form.pdf", "mapping.yml")
# => { total: 92, renamed: 80, disambiguated: 2, skipped_null: 10, stale: 0 }
```

If you've already compiled an engine for this PDF (for example to also call `Schema.infer`), pass it in to avoid a second compile pass:

```ruby
engine = AcroForge::Engine.new("form.pdf")
engine.compile!

schema = AcroForge::Schema.infer("form.pdf", engine: engine)
AcroForge::Relabeler.propose("form.pdf", out: "mapping.yml", schema: schema, engine: engine)
```

`apply!` validates every `key` value before writing anything. If any key fails the `/\A[a-z][a-z0-9_]*\z/` check, it raises `RelabelError` and leaves the PDF untouched. Collisions (two entries with the same key) are auto-disambiguated with `_1`, `_2` suffixes; the result's `disambiguated` counter tells you how many fields ended up suffixed. Stale entries (mapping keys that don't match any field in the PDF) emit warnings to `$stderr` and are counted in `stale`.

### `AcroForge::Validator`

Validates individual values against AcroForge field types.

```ruby
AcroForge::Validator.valid?("alice@example.com", :email)  # => true
AcroForge::Validator.valid?("not a date", :date)          # => false
```

Supported types: `string`, `select`, `boolean`, `money`, `date`, `email`, `number`.

## Errors

- `AcroForge::ValidationError`: raised by `Engine#validate_payload!` on type mismatch.
- `AcroForge::RelabelError`: raised by `Relabeler.apply!` on malformed mapping YAML, invalid key names, or missing AcroForm.

Both errors inherit from `StandardError`. The CLI translates them to exit code `2` (validation errors) versus `1` (user errors like missing files); embedding callers can rescue them directly.

## Suppressing engine output

`Engine#compile!` prints per-field reasoning to stdout (`[Auto-Mapped]`, `[Failed]`, etc.) which is useful for debugging but noisy in production. The CLI silences this by default and re-enables it under `--verbose`. Library callers can do the same by redirecting `$stdout` temporarily:

```ruby
def silenced
  orig = $stdout
  null = File.open(File::NULL, "w")
  $stdout = null
  yield
ensure
  $stdout = orig
  null&.close
end

silenced do
  engine.compile!
  AcroForge::Schema.infer("form.pdf", engine: engine)
end
```
