# Relabeling Workflow

## The four-phase model

AcroForge's relabeling workflow is intentionally split into four discrete phases rather than running end-to-end automatically:

1. **Infer schema** (`acroforge schema infer`) — the heuristic scans the PDF and proposes a canonical schema: field keys, types, and the label variations it observed. The output is a YAML file you review and edit.
2. **Propose mapping** (`acroforge relabel propose`) — the engine runs again with your (reviewed) schema and generates a per-field mapping file: one entry per AcroForm field, proposing which canonical key it should be renamed to.
3. **Human review** — you open the mapping file in an editor. For every field the heuristic got wrong, you correct the `key` (or set it to `~` to leave the field unchanged). The `meta` block beside each entry shows the raw label text and confidence level to help you decide.
4. **Apply rename** (`acroforge relabel apply`) — AcroForge reads the corrected mapping and permanently rewrites `field[:T]` (internal name) and `field[:TU]` (tooltip) inside the PDF. No changes are written until all keys pass validation.

This design lets you preserve human judgment at the points where the heuristic is uncertain — rather than silently producing a PDF with a mix of good and bad renames, it surfaces the uncertain fields for your review and only commits once you've signed off.

## How the heuristic works

For each AcroForm field, AcroForge:

1. Reads every text chunk on the page along with its bounding box.
2. Scores nearby text against the field's widget rectangle using a mode-aware weighted heuristic (Grid-Lock, Inline Paragraph, or Standard Label depending on layout).
3. Picks the best-scoring label, sanitises it into a snake-case key.
4. If a `schema` is supplied, canonicalises the key against its `variations` lists.
5. For radio groups and checkboxes, also discovers the option export values from the widget appearance states.

The three scoring modes handle the main PDF layout patterns:

- **Standard Label** — a text run appears directly above, to the left of, or immediately adjacent to the field widget. The most common case.
- **Grid-Lock** — the form is laid out as a grid and labels are in a separate column. The heuristic uses horizontal and vertical alignment to find the correct cell header.
- **Inline Paragraph** — the field is embedded inside a sentence or paragraph. The heuristic extracts the closest preceding noun phrase.

You can inspect the raw scoring data after `compile!` by calling `engine.field_proposals`. This is the same data structure the Relabeler consumes when generating the mapping file, so it's useful for debugging cases where the heuristic picks the wrong label.

## Why human review matters

The heuristic achieves high accuracy on well-structured forms, but every PDF is different. Common failure modes:

- **Ambiguous proximity** — two labels are equidistant from the field widget, so the scorer picks arbitrarily.
- **Rotated or floating labels** — labels placed at an angle or far from their fields in the coordinate system.
- **Missing labels** — some fields have no visible label at all (e.g., a continuation field on a second page).
- **Vendor inconsistency** — the same form reused across years with slightly different label text each time.

In all these cases the mapping file's `confidence` value will be `medium` or `low`, and the `meta.raw_label` will be blank or surprising. Those are the entries worth double-checking before applying.

Because `apply!` validates every key before writing anything and raises `RelabelError` on the first violation, a single bad entry blocks the whole apply — giving you another checkpoint before any PDF is modified.
