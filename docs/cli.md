# CLI Reference

## Synopsis

```
acroforge schema infer <pdf>     [--out schema.yml] [--sections a,b,c]
acroforge relabel propose <pdf>  [--out mapping.yml] [--schema schema.yml] [--merge|--overwrite]
acroforge relabel apply <pdf> <mapping.yml>
acroforge compile <pdf>          [--schema schema.yml]
acroforge bootstrap <pdf>        [--schema-out s.yml] [--mapping-out m.yml]
acroforge version
acroforge help
```

## Subcommands

| Subcommand | What it does |
|---|---|
| `schema infer` | Runs the heuristic on a PDF and writes a starter schema (canonical key → type + variations). Advisory; you review and edit. |
| `relabel propose` | Writes a YAML mapping file proposing a semantic name for every AcroForm field. Sorted by page → top-to-bottom → left-to-right. Default mode `--merge` preserves any `key`/`type` values you've already edited. |
| `relabel apply` | Reads a corrected mapping file and rewrites `field[:T]` / `field[:TU]` in the source PDF in place. Auto-disambiguates collisions (`full_name`, `full_name_1`, ...). |
| `compile` | Diagnostic: runs the engine and prints mapped/unmapped counts. Useful for checking heuristic coverage without writing any files. |
| `bootstrap` | Convenience: `schema infer` + `relabel propose` in one call. |

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | User error (bad arguments, missing file) |
| `2` | Validation error |
| `3` | Internal error |

---

## `schema infer`

Runs the spatial heuristic on the given PDF and writes a starter schema YAML file mapping canonical keys to types and label variations. The output is advisory. Open it in an editor to correct any guesses before passing it to `relabel propose`.

```bash
acroforge schema infer application.pdf --out schema.yml
acroforge schema infer application.pdf --out schema.yml --sections "Personal Details,Loan Details"
```

Use `--sections` to restrict heuristic scoring to specific section headings visible in the PDF. This narrows the candidate label pool and improves accuracy on dense forms.

---

## `relabel propose`

Generates a per-field YAML mapping file proposing a semantic rename for every AcroForm field in the PDF. Fields are sorted by page → top-to-bottom → left-to-right so the file reads naturally when you review it.

```bash
acroforge relabel propose broken_form.pdf --schema schema.yml --out mapping.yml
```

**`--merge` (default):** If `mapping.yml` already exists, preserves any `key` or `type` values you've hand-edited and only overwrites the fields that are still unresolved.

**`--overwrite`:** Regenerates the mapping file from scratch, discarding any manual edits.

---

## `relabel apply`

Reads a corrected mapping file and permanently rewrites `field[:T]` (internal name) and `field[:TU]` (tooltip) in the source PDF. Writes the changes in place.

```bash
acroforge relabel apply broken_form.pdf mapping.yml
```

If two fields resolve to the same key, `apply` auto-disambiguates by appending `_1`, `_2`, etc. (`full_name`, `full_name_1`). If a `key` value fails validation (must match `/\A[a-z][a-z0-9_]*\z/`), `apply` raises `RelabelError` and writes nothing. The PDF is left untouched.

---

## `compile`

Diagnostic command. Runs the engine pipeline and prints a summary of how many fields were mapped, how many remain unmapped, and which schema keys had no match. Does not write any files.

```bash
acroforge compile application.pdf --schema schema.yml
```

Use this after editing your schema to check heuristic coverage before committing to a full `relabel propose` run.

---

## `bootstrap`

Convenience wrapper that runs `schema infer` followed by `relabel propose` in a single call. Useful when starting from scratch with a new PDF.

```bash
acroforge bootstrap broken_form.pdf
# writes schema.yml and mapping.yml in the current directory

acroforge bootstrap broken_form.pdf --schema-out my_schema.yml --mapping-out my_mapping.yml
```

---

## `version`

Prints the installed AcroForge version and exits.

```bash
acroforge version
# => AcroForge 0.1.0
```

---

## `help`

Prints usage information for all subcommands.

```bash
acroforge help
acroforge help relabel propose
```
