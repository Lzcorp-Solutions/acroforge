# CHANGELOG

## [0.3.0] - 2026-06-01

### Added

- **`acroforge fields <pdf>` CLI subcommand** — lists every AcroForm field's name, type, and alternate name as an aligned table, or as JSON with `--json`. Decoded options maps render inline (table) or as nested objects (JSON). A PDF without an AcroForm prints a notice and still exits `0`.

### Changed

- **`Engine#fields` decodes persisted options maps.** When `/TU` holds the JSON options map that `compile!` writes for button/choice fields, `:alternate_name` is now returned as a symbol-keyed Hash (e.g. `{ male: "0", female: "1" }`) instead of the raw JSON string. Plain-text tooltips and missing `/TU` entries are unaffected (still String / `nil`).
- **Image stamping extracted to `AcroForge::ImageStamper`** (internal). `Engine#fill!` behavior, the `ImageTooLargeError` / `UnsupportedImageFormatError` classes, and the validation rules are unchanged; the `MAX_IMAGE_BYTES` / `MAX_IMAGE_DIMENSION` / `TARGET_PPI` constants now live on `ImageStamper` instead of `Engine`.

### Fixed

- **Choice fields now auto-map.** `compile!` built options maps for combo/list boxes from `/Opt` but never ran the spatial label lookup on them, so a garbage-named choice field always landed in `unmapped` and its options were discarded. Choice fields now get the same nearest-label resolution as text fields, and their options persist to `/TU` and `select_options`.

### Internal

- Synthetic fixture PDFs now carry `/AP` appearance streams on radio/checkbox widgets, so `compile!`'s options-map discovery runs against them in CI. New round-trip spec covers compile! → fields → fill! through the persisted `/TU` map.

## [0.2.0] - 2026-05-28

### Changed (breaking)

- **`_btn` suffix dropped from canonical keys.** Button/choice fields now use bare canonical keys (`gender`, `title`, `marital_status`) instead of `gender_btn` etc. Type detection for validation reads the PDF field type and the resolved options map, not a string token in the key. Existing payloads/schemas/mappings using `_btn` need their keys updated.
- **`fill!` is now standalone.** It no longer requires `compile!` to have run, and it no longer falls back to the normalized PDF — it always fills the original `@template_path`. Stale normalized files can no longer silently take over a fill. To fill a renamed template, instantiate a new `Engine` over the normalized output.
- **Bad radio values now raise instead of warn-and-skip.** When `fill!` cannot match a value to a radio button's allowed options, it raises `AcroForge::Error` instead of logging a warning and continuing.
- **Engine introspection renamed:** `raw_fields` → `fields`, `raw_field_names` → `field_names`, `any_raw_fields?` → `any_fields?`.
- **Schemas emitted by `Schema.infer` / `Schema.merge` no longer carry empty `variations: []`.** When a field has no spatial label worth recording (typically anything preserved verbatim), the key is omitted entirely. Existing schemas with `variations:` still load fine.
- **Parenthetical content stripped** from both canonical keys and humanized variations. `Date of Birth (YYYY-MM-DD)` now produces `:date_of_birth` (not `:date_of_birth_yyyy_mm_dd`) and the variation `"Date of Birth"`.

### Added

- **`preserve:` constructor kwarg on `Engine`** — explicit allowlist of AcroForm field names `compile!` must never rename. Plumbed through `Schema.infer` and `Relabeler.propose`.
- **Auto-preserve cascade in `compile!`** — fields are kept verbatim when they are (A) in `preserve:`, (B) a schema canonical key, or (C) look like a clean snake_case identifier (`looks_like_clean_identifier?`). Tier C is what makes `schema infer` on a clean PDF stop generating `mr` / `single` / section-header bleeds.
- **Case-insensitive radio matching** in `fill!` — `"Mr"` resolves to `:mr` against `allowed_values` without forcing the caller to know the export-value casing.
- **Automatic image stamping in `fill!`** — a payload value that targets a push-button image-upload field and points to a JPG/PNG file path is now drawn into the widget rectangle (scaled to fit) instead of being treated as text. `compile!` infers canonical keys for these slots from widget geometry: square-ish → `:passport_photo`, wide-and-thin → `:signature`, otherwise `:photo`.
- **Image validation with new error classes** — stamped images must be JPG or PNG within `MAX_IMAGE_BYTES` (5 MB) and `MAX_IMAGE_DIMENSION` (4000 px per side); violations raise the new `AcroForge::ImageTooLargeError` or `AcroForge::UnsupportedImageFormatError` (both subclass `AcroForge::Error`). When ImageMagick (`convert`) is on `PATH`, oversized images are downsampled toward `TARGET_PPI` (200) and transparent PNG borders (e.g. around a signature) are trimmed before stamping.
- **`simplecov`** in the dev/test group; coverage report under `coverage/`.

### Fixed

- Radio button widget appearance state (`/AS`) wasn't syncing when `fill!` operated standalone (no compile-time `:TU` options map). Radios now coerce values to a Symbol matched against `allowed_values`, so hexapdf syncs widget state correctly.
- `Schema.infer_type` was missing matches on snake_case names (`account_no`, `date_signed`) because `_` is a word character — regex `\b` never fired. Underscores are now normalized to spaces before type detection.
- `Schema.infer_type` now recognises `\bdob\b` as a date.
- `Schema.merge` no longer reinstates the empty `variations: []` keys that `aggregate_proposals` strips.
- `compile!` was reading `field[:Opt]` for choice fields via `is_a?(Array)`, but hexapdf 1.x returns `HexaPDF::PDFArray` (not `Array`). The check is now duck-typed via `respond_to?(:each)`, so choice-field options maps are populated correctly.
- Spatial `:standard` scorer no longer claims a label sitting two rows above a field — tightened `dy_top` window and gave inline (label-left) matches a stronger preference over grid-locked (label-above) candidates. This recovers `first_name` on multi-column form layouts like Abokobi's.

## [0.1.0] - 2026-05-26

## Added

- `AcroForge::Engine`: PDF AcroForm compilation with spatial heuristic and DI'd schema/overrides.
- `AcroForge::Schema`: load, dump, normalize, and infer schemas (YAML or JSON).
- `AcroForge::Relabeler`: propose and apply field renames via heuristic-derived YAML mappings.
- `AcroForge::Validator`: type validation for payloads.
- CLI: `acroforge schema|relabel|compile|bootstrap|version|help`.
