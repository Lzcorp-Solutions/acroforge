---
layout: home

hero:
  name: AcroForge
  text: AcroForm PDFs, forged clean.
  tagline: A Ruby toolkit for reading, validating, relabeling, and filling PDF AcroForms — especially the broken ones.
  actions:
    - theme: brand
      text: Quick Start
      link: /quick-start
    - theme: alt
      text: View on GitHub
      link: https://github.com/youruser/acroforge

features:
  - title: Relabel garbage-named fields
    details: When a vendor ships you a fillable PDF with fields named "page0_field6" or "Text101", AcroForge runs a spatial heuristic to figure out what each field is actually for, writes its proposal to a human-reviewable YAML file, and permanently renames the AcroForm fields once you've approved.
  - title: Domain-agnostic
    details: Works on any AcroForm PDF — loan applications, school admissions, government forms, internal HR templates. Nothing in the gem is domain-specific.
  - title: Schema-driven
    details: Define your canonical field set once. AcroForge canonicalises labels across vendor variations ("First Name", "Surname", "Given Name") into a single key.
  - title: CLI + Library
    details: Drive it from a one-line shell command (`acroforge bootstrap form.pdf`) or embed it in your Ruby application.
---

## What it does

AcroForge reads, validates, relabels, and fills PDF AcroForms. Its standout feature is the **relabeling workflow**: when a vendor ships you a fillable PDF whose internal field names look like `page0_field6`, `Text101`, or worse, AcroForge runs a spatial heuristic to figure out what each field is *actually* for, writes its proposal to a human-reviewable YAML file, and then permanently renames the AcroForm fields once you've approved the mapping. The result is a PDF you can fill programmatically without ever again writing `pdf.fields["page0_field6"] = "Alice"`.

It works on any AcroForm PDF — loan applications, school admission forms, government paperwork, internal HR templates. Nothing in the gem is domain-specific.
