# Quick Start

## The relabeling workflow

AcroForge's core workflow has four phases:

1. **Infer schema**: run the spatial heuristic on the PDF to produce a starter schema that maps canonical keys to field types and label variations.
2. **Propose mapping**: generate a per-field YAML file that proposes a semantic rename for every AcroForm field, sorted by page position.
3. **Human review**: open the mapping file in your editor. Fix any wrong proposals, fill in blanks, and set `key: ~` for fields you want to leave unchanged.
4. **Apply rename**: AcroForge reads the corrected mapping and permanently rewrites the field names inside the PDF. After this step the PDF is yours to fill with clean, semantic keys.

This design keeps the heuristic in an advisory role and puts you in control of any rename it gets wrong.

## Step-by-step example

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

After step 4, the PDF's internal field names are semantic (`full_name`, `email`, `gender`, ...) and you can fill the form programmatically with confidence:

```ruby
engine = AcroForge::Engine.new("broken_form.pdf", schema: AcroForge::Schema.load("schema.yml"))
engine.fill!({ full_name: "Alice", email: "alice@example.com" }, "filled.pdf")
```

## Bootstrap shortcut

Steps 1 and 2 can be collapsed into a single command:

```bash
$ acroforge bootstrap broken_form.pdf
# writes schema.yml AND mapping.yml in one pass
```

Use `bootstrap` when starting fresh with a new PDF. Use `schema infer` + `relabel propose` separately when you already have a schema you want to reuse across multiple PDFs from the same vendor.
