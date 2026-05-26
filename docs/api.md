# Library API

## CLI vs Library API

Use the CLI (`acroforge bootstrap`, `acroforge relabel apply`, ...) for one-off tasks, CI pipelines, or shell scripts where you just need to process a PDF and move on.

Use the library API when you need to embed AcroForge inside a Ruby application — for example, to fill forms as part of a loan origination flow, to inspect field proposals programmatically before deciding whether to apply them, or to integrate AcroForge's validation into your own error-handling layer.

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

- `mapped` — canonical key → widget metadata for every field the heuristic resolved
- `unmapped` — list of AcroForm field names that couldn't be matched to a schema key
- `select_options` — discovered export values for radio/checkbox groups
- `new_fields_detected` — schema keys that appear in the PDF but weren't in your schema

After `compile!`, call `engine.field_proposals` to inspect the raw per-field scoring data that the Relabeler consumes.

### `AcroForge::Schema`

Loads, normalises, infers, and dumps schema files.

```ruby
# Generate a starter schema from a PDF.
schema = AcroForge::Schema.infer("form.pdf")
AcroForge::Schema.dump(schema, "schema.yml")
```

`Schema.load` accepts a file path (YAML or JSON) or a Hash. It normalises shorthand schemas (where values are arrays of variations) into the rich form on the way in.

### `AcroForge::Relabeler`

Runs the propose and apply phases programmatically.

```ruby
# Run the relabeler programmatically.
AcroForge::Relabeler.propose("form.pdf", out: "mapping.yml", schema: schema)
AcroForge::Relabeler.apply!("form.pdf", "mapping.yml")
```

`apply!` validates every `key` value before writing anything. If any key fails the `/\A[a-z][a-z0-9_]*\z/` check, it raises `RelabelError` and leaves the PDF untouched.

### `AcroForge::Validator`

Validates individual values against AcroForge field types.

```ruby
# Validate individual values.
AcroForge::Validator.valid?("alice@example.com", :email)  # => true
AcroForge::Validator.valid?("not a date", :date)          # => false
```

Supported types: `string`, `select`, `boolean`, `money`, `date`, `email`, `number`.

## Errors

- `AcroForge::ValidationError` — raised by `Engine#validate_payload!` on type mismatch.
- `AcroForge::RelabelError` — raised by `Relabeler.apply!` on malformed mapping YAML, invalid key names, or missing AcroForm.

Both errors inherit from `AcroForge::Error` so you can rescue either with a single `rescue AcroForge::Error`.
