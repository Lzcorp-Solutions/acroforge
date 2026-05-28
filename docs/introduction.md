# Introduction

AcroForge is a Ruby toolkit for working with PDF AcroForms, the interactive form layer embedded in many fillable PDFs. It does three things: it reads AcroForms, fills them, and most importantly **relabels them** when the vendor's internal field names are unusable.

## The problem

PDF authoring tools let designers give every field any name they like. In practice, most don't. You will regularly receive "fillable" PDFs whose AcroForm dictionary looks like this:

```
page0_field6
page0_field28
page0_field33
Text101
Text107
```

These names tell you nothing about which field is the applicant's name, which is the email, or which is the loan amount. Filling such a PDF programmatically means building a mapping from cryptic names to semantic meaning by hand: opening the PDF in a viewer, clicking each field, writing down what it represents. That work is tedious, error-prone, and has to be redone every time the vendor ships a new revision.

## What AcroForge does

AcroForge automates the discovery and keeps a human in the loop where the machine might be wrong. The workflow has four phases:

1. **Discover.** A spatial heuristic scans the PDF, finds the nearest visible label for every cryptic field, and proposes a semantic name.
2. **Review.** Proposals are written to a plain YAML file you open in an editor. Override wrong guesses, accept the rest. Set `key: ~` to skip any field you want to leave alone.
3. **Apply.** A second command rewrites the AcroForm dictionary in place, replacing `page0_field6` with `full_name`, `page0_field28` with `applicant_email`, and so on. Collisions auto-disambiguate (`full_name`, `full_name_1`, ...).
4. **Fill.** The PDF is now addressable by name from any Ruby script, or any other language that can read AcroForms.

Once the rename is applied, the PDF is permanently fixed. Any downstream tooling can fill it without ever knowing the cryptic original names.

## When to use AcroForge

- You receive vendor PDFs with garbage AcroForm field names and need to fill them programmatically.
- Forms change occasionally and you want a workflow that survives revisions without re-mapping by hand.
- You're building a filling pipeline that targets many similar-but-slightly-different PDF templates from different vendors.

## When not to use AcroForge

- The PDF isn't an AcroForm at all. AcroForge won't help you fill a scanned image, a static PDF, or a PDF whose form layer is in XFA rather than AcroForm.
- You control the form's authoring. If you can name your fields properly at design time, just do that. AcroForge solves a problem you don't have.

## The shape of the gem

AcroForge ships six public modules and a CLI:

| Module                  | What it's for                                            |
| ----------------------- | -------------------------------------------------------- |
| `AcroForge::Engine`     | Compile, validate, and fill an AcroForm.                 |
| `AcroForge::Schema`     | Declare, infer, merge, load and dump canonical schemas.  |
| `AcroForge::Relabeler`  | Produce and apply the rename mapping.                    |
| `AcroForge::Preparer`   | Disambiguate AcroForms that ship with duplicate field names. |
| `AcroForge::Annotator`  | Render a labeled PDF for visual review of proposals.     |
| `AcroForge::Validator`  | Type checks on payload values.                           |

The CLI (`acroforge`) wraps the same module surface. Pick whichever fits your workflow. The engine works the same either way.

> **`fill!` is standalone.** If the PDF's field names are already semantic (yours, or output from `acroforge relabel apply`), you can skip the relabeling workflow entirely and call `Engine#fill!` directly. The four-phase workflow exists for *vendor* PDFs that ship with garbage names.

## Where to go next

- **[Installation](./installation)**: get the gem onto your machine and on your `PATH`.
- **[Quick Start](./quick-start)**: run the bootstrap workflow against your first PDF in five minutes.
- **[Relabeling Workflow](./relabeling)**: the conceptual deep-dive on how the heuristic + human-review loop works.
- **[CLI Reference](./cli)**: every subcommand and flag.
- **[Library API](./api)**: the Ruby surface in detail.
