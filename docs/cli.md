# CLI Reference

## Synopsis

```
acroforge fields <pdf>           [--json]
acroforge schema infer <pdf>     [--out schema.yml] [--sections a,b,c] [-v]
acroforge schema merge <mapping.yml> [--schema schema.yml] [--out schema.yml]
acroforge relabel propose <pdf>  [--out mapping.yml] [--schema schema.yml] [--merge|--overwrite] [-v]
acroforge relabel apply <pdf> <mapping.yml> [--annotate[=PATH]] [-v]
acroforge compile <pdf>          [--schema schema.yml]
acroforge bootstrap <pdf>        [--schema-out s.yml] [--mapping-out m.yml] [-v]
acroforge annotate <pdf>         [--mapping mapping.yml] [--out annotated.pdf]
acroforge prepare <pdf>          [--out prepared.pdf] [--schema schema.yml]
acroforge version
acroforge help
```

## Subcommands

| Subcommand | What it does |
|---|---|
| `fields` | Lists every AcroForm field — name, type, alternate name — as a table or JSON. Read-only; the quickest way to see what's inside a PDF. |
| `schema infer` | Runs the heuristic on a PDF and writes a starter schema (canonical key → type + variations). Advisory; you review and edit. |
| `schema merge` | Folds hand-reviewed decisions from a `mapping.yml` back into a `schema.yml`. Stops the mapping and schema from drifting apart over time. |
| `relabel propose` | Writes a YAML mapping file proposing a semantic name for every AcroForm field. Sorted by page → top-to-bottom → left-to-right. Default mode `--merge` preserves any `key`/`type` values you've already edited. |
| `relabel apply` | Reads a corrected mapping file and rewrites `field[:T]` / `field[:TU]` in the source PDF in place. Auto-disambiguates collisions (`full_name`, `full_name_1`, ...). |
| `compile` | Diagnostic: runs the engine and prints mapped/unmapped counts. Useful for checking heuristic coverage without writing any files. |
| `bootstrap` | Convenience: `schema infer` + `relabel propose` in one call. |
| `annotate` | Render a copy of the PDF with every field labeled inline (optionally colour-coded against a mapping) for visual review. |
| `prepare` | Resolves duplicate-named fields in the PDF by giving each occurrence a unique heuristic-proposed name. Run before bootstrap when the PDF has duplicates. |

## Verbose mode

By default, `bootstrap`, `schema infer`, `relabel propose`, and `relabel apply` print only a one-line summary of what they did. Pass `-v` or `--verbose` to also see the engine's per-field reasoning on stdout:

```
   [Auto-Mapped] 'Full Name' -> :full_name
   [Auto-Mapped] 'Tax Identification No.' -> :tax_identification_no
   ...
   [Failed] Could not find a text label for field: Image1_af_image
```

`compile` always prints the engine output. That's its purpose.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | User error (bad arguments, missing file) |
| `2` | Validation error (`ValidationError`, `RelabelError`) |
| `3` | Internal error |

---

## `fields`

Lists every AcroForm field in the PDF — internal name, type, and alternate name (`/TU`) — without modifying anything. Run it before deciding whether a PDF needs relabeling, or after `compile!` to confirm what got persisted.

```bash
acroforge fields application.pdf
# NAME                 TYPE    ALTERNATE NAME
# full_name            text    —
# gender               button  {male: "male", female: "female"}
# marital_status       choice  {single: "Single", married: "Married", divorced: "Divorced", widowed: "Widowed"}
# passport_photo       button  —
```

For compiled (normalized) PDFs, button and choice fields show their decoded options map: the payload values `fill!` accepts on the left, the PDF's internal export values on the right. Plain tooltips display as-is; fields without a `/TU` entry show `—`.

```bash
acroforge fields application.pdf --json
```

`--json` emits the same data as a JSON array — option maps as nested objects, missing alternate names as `null` — for piping into `jq` or other tools:

```json
[
  {
    "name": "gender",
    "type": "button",
    "alternate_name": {
      "male": "male",
      "female": "female"
    }
  }
]
```

A PDF with no AcroForm fields prints `No AcroForm fields found in <pdf>.` and still exits `0` — absence of fields is an answer, not an error.

---

## `schema infer`

Runs the spatial heuristic on the given PDF and writes a starter schema YAML file mapping canonical keys to types and label variations. The output is advisory. Open it in an editor to correct any guesses before passing it to `relabel propose`.

```bash
acroforge schema infer application.pdf --out schema.yml
acroforge schema infer application.pdf --out schema.yml --sections "Personal Details,Loan Details"
```

Use `--sections` to restrict heuristic scoring to specific section headings visible in the PDF. This narrows the candidate label pool and improves accuracy on dense forms.

On success, prints a one-line summary:

```
Wrote schema.yml: 14 canonical keys inferred.
```

---

## `schema merge`

Folds hand-reviewed decisions from a `mapping.yml` back into a `schema.yml` so the two files don't drift apart. Each mapping entry with a non-null `key:` contributes the canonical key (stripped of any `_N` collision suffix), its type, and its `raw_label` as a variation.

```bash
# Update schema.yml in place
acroforge schema merge mapping.yml --schema schema.yml

# Write the merged schema to a different file
acroforge schema merge mapping.yml --schema schema.yml --out updated_schema.yml
```

When to use it: you ran `bootstrap`, hand-edited `mapping.yml` to change a proposed key (e.g., `full_name` → `applicant_name`), then ran `relabel apply` to commit the change. Apply only mutates the PDF — `schema.yml` still holds the old vocabulary. Run `schema merge` to teach the schema what you decided, so future bootstraps on similar PDFs propose your preferred key.

The schema's existing entries keep their types but gain any new label variations. Entries with `key: nil` and reserved `_meta` keys are skipped.

On success, prints a one-line summary:

```
Merged into schema.yml: 1 new key added, 3 existing keys updated.
```

---

## `relabel propose`

Generates a per-field YAML mapping file proposing a semantic rename for every AcroForm field in the PDF. Fields are sorted by page → top-to-bottom → left-to-right so the file reads naturally when you review it.

```bash
acroforge relabel propose broken_form.pdf --schema schema.yml --out mapping.yml
```

**`--merge` (default):** If `mapping.yml` already exists, preserves any `key` or `type` values you've hand-edited and only refreshes the advisory `meta:` blocks.

**`--overwrite`:** Regenerates the mapping file from scratch, discarding any manual edits.

On success, prints:

```
Wrote mapping.yml: 82 of 92 fields proposed; 10 need manual review.
```

The "need manual review" count is the number of fields where the heuristic found no nearby label and left `key: ~`. Those are the rows you fill in by hand before running `relabel apply`.

---

## `relabel apply`

Reads a corrected mapping file and permanently rewrites `field[:T]` (internal name) and `field[:TU]` (tooltip) in the source PDF. Writes the changes in place.

```bash
acroforge relabel apply broken_form.pdf mapping.yml

# Also write a colour-coded review PDF showing the mapping plan
acroforge relabel apply broken_form.pdf mapping.yml --annotate

# Write the review snapshot to a custom path (for audit trails / archives)
acroforge relabel apply broken_form.pdf mapping.yml --annotate=audit/2026-05-27.pdf
```

If two fields resolve to the same key, `apply` auto-disambiguates by appending `_1`, `_2`, etc. (`full_name`, `full_name_1`). If a `key` value fails validation (must match `/\A[a-z][a-z0-9_]*\z/`), `apply` raises `RelabelError` and writes nothing. The PDF is left untouched.

### `--annotate[=PATH]`

Optional. When passed, generates an annotated review PDF *before* the rename is applied, so the badges show `original_field_name -> proposed_key` (post-rename annotation would show every entry as stale and be useless).

- `--annotate` with no value writes to `<source>_annotated.pdf` (overwriting if present), matching the default of `acroforge annotate`.
- `--annotate=path/to/review.pdf` writes to an explicit path — useful when you want a dated audit snapshot like `audit/2026-05-27.pdf` that won't be overwritten by the next annotate run.

Note OptionParser's convention for optional values: use `--annotate=path.pdf` (with the equals sign) to pass a path. `--annotate path.pdf` without the equals would treat `path.pdf` as the next positional argument instead.

On success, prints a one-line summary:

```
Applied to broken_form.pdf: 7 renamed, 2 disambiguated, 91 skipped (no key).
```

Possible summary parts:

- `N renamed` — fields whose names were rewritten.
- `N disambiguated` — of those, how many got `_1`/`_2`/... appended because of key collisions.
- `N skipped (no key)` — entries with `key: ~` were left alone.
- `N stale` — entries whose PDF field name no longer exists in the source PDF. Also surfaces individual `acroforge: stale entry ...` warnings on stderr.

### Duplicate field names

Some PDFs contain multiple AcroForm fields all sharing the same `:T` name (e.g., three separate fields all literally named `date`). `bootstrap` writes these as separate entries using a `#N` suffix to keep YAML keys unique:

```yaml
date:                     # first occurrence
  key: signature_date
  type: date
date#1:                   # second occurrence
  key: confirmed_date
  type: date
date#2:                   # third occurrence
  key: final_date
  type: date
```

`apply` resolves each suffix back to the correct field by occurrence order. You never have to think about the `#N` suffix unless your PDF has duplicates — uniquely-named fields keep the bare name.

---

## `compile`

Diagnostic command. Runs the engine pipeline and prints how many fields were mapped versus unmapped. Does not write any files.

```bash
acroforge compile application.pdf --schema schema.yml
# Mapped: 65, Unmapped: 5
```

Use this after editing your schema to check heuristic coverage before committing to a full `relabel propose` run. Unlike the other subcommands, `compile` always prints the engine's per-field log — that's its purpose.

---

## `annotate`

Renders a copy of the PDF with every AcroForm field labeled inline. Useful when you need to correlate cryptic field names (`page0_field6`, `Text101`) to what's visible on the page — usually when reviewing a `mapping.yml` and trying to figure out which physical field a particular entry refers to.

```bash
# Bare annotation: each field labeled with its current internal name
acroforge annotate broken_form.pdf
# Wrote broken_form_annotated.pdf: 98 fields annotated.

# With a mapping: show "original_name -> proposed_key" per field, colour-coded
acroforge annotate broken_form.pdf --mapping mapping.yml --out review.pdf
# Wrote review.pdf: 98 fields annotated (82 mapped, 10 no key, 6 not in mapping).
```

The output PDF is identical to the source except for an overlay drawn on each field:

- **Green badge**: the mapping has a `key:` value for this field. After `relabel apply`, it'll be renamed to that key.
- **Amber badge**: the mapping has the field but its `key:` is `~` (null). You need to fill it in by hand.
- **Gray badge**: the field exists in the PDF but isn't in the mapping at all (probably an image stamp or a field added after the mapping was generated).
- **Blue badge** (bare mode, no `--mapping`): just the field's current name.

Text-input badges sit inside the empty field area so they don't obscure the form's own labels. Checkbox / radio badges sit above the field.

Output defaults to `<source>_annotated.pdf` next to the input.

---

## `prepare`

Resolves PDF-internal naming conflicts (multiple AcroForm fields literally sharing the same `:T` name) by giving each duplicate a unique heuristic-proposed name before the mapping is generated. Run this once at the start of the workflow if your PDF has duplicates; it's a no-op otherwise.

```bash
# Modify the PDF in place
acroforge prepare broken_form.pdf

# Or write a prepared copy to a different file
acroforge prepare broken_form.pdf --out broken_form_prepared.pdf

# Use a schema for canonicalization while resolving
acroforge prepare broken_form.pdf --schema schema.yml
```

Without this step, fields named (say) `date`, `date`, `date` collapse to a single YAML entry in the mapping (because YAML keys are unique). `bootstrap` handles them by writing `date`, `date#1`, `date#2` as synthetic suffixes, but the `#N` suffix is ugly to read and edit. `prepare` resolves them up front using the heuristic's proposals, so the resulting `mapping.yml` has clean unique top-level keys.

On success, prints a one-line summary:

```
Prepared in place: 1 duplicate groups, 3 duplicates renamed.
```

When the PDF has no duplicates:

```
Nothing to do: broken_form.pdf has no duplicate field names.
```

---

## `bootstrap`

Convenience wrapper that runs `schema infer` followed by `relabel propose` against the same compile pass. Useful when starting from scratch with a new PDF.

```bash
acroforge bootstrap broken_form.pdf
# writes schema.yml and mapping.yml in the current directory

acroforge bootstrap broken_form.pdf --schema-out my_schema.yml --mapping-out my_mapping.yml
```

Unlike running `schema infer` and `relabel propose` sequentially, `bootstrap` only compiles the engine once. In verbose mode you see the engine log once, not twice. On success, prints both summaries:

```
Wrote schema.yml: 14 canonical keys inferred.
Wrote mapping.yml: 82 of 92 fields proposed; 10 need manual review.
```

---

## `version`

Prints the installed AcroForge version and exits.

```bash-vue
acroforge version
# {{ $version }}
```

---

## `help`

Prints usage information for all subcommands.

```bash
acroforge help
```
