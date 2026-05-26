# CLI Reference

## Synopsis

```
acroforge schema infer <pdf>     [--out schema.yml] [--sections a,b,c] [-v]
acroforge relabel propose <pdf>  [--out mapping.yml] [--schema schema.yml] [--merge|--overwrite] [-v]
acroforge relabel apply <pdf> <mapping.yml> [-v]
acroforge compile <pdf>          [--schema schema.yml]
acroforge bootstrap <pdf>        [--schema-out s.yml] [--mapping-out m.yml] [-v]
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
```

If two fields resolve to the same key, `apply` auto-disambiguates by appending `_1`, `_2`, etc. (`full_name`, `full_name_1`). If a `key` value fails validation (must match `/\A[a-z][a-z0-9_]*\z/`), `apply` raises `RelabelError` and writes nothing. The PDF is left untouched.

On success, prints a one-line summary:

```
Applied to broken_form.pdf: 7 renamed, 2 disambiguated, 91 skipped (no key).
```

Possible summary parts:

- `N renamed` — fields whose names were rewritten.
- `N disambiguated` — of those, how many got `_1`/`_2`/... appended because of key collisions.
- `N skipped (no key)` — entries with `key: ~` were left alone.
- `N stale` — entries whose PDF field name no longer exists in the source PDF. Also surfaces individual `acroforge: stale entry ...` warnings on stderr.

---

## `compile`

Diagnostic command. Runs the engine pipeline and prints how many fields were mapped versus unmapped. Does not write any files.

```bash
acroforge compile application.pdf --schema schema.yml
# Mapped: 65, Unmapped: 5
```

Use this after editing your schema to check heuristic coverage before committing to a full `relabel propose` run. Unlike the other subcommands, `compile` always prints the engine's per-field log — that's its purpose.

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

```bash
acroforge version
# 0.1.0
```

---

## `help`

Prints usage information for all subcommands.

```bash
acroforge help
```
