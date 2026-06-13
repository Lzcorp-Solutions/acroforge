---
layout: home
title: "AcroForge: AcroForms, forged clean."
titleTemplate: false
---

<section class="af-section af-section--dark af-hero">
  <div class="af-section-inner af-hero-grid">
    <div>
      <h1 class="af-headline">AcroForms,<br /><em>forged clean.</em></h1>
      <p class="af-lede">Take a broken-named PDF form and make it programmatically fillable in three commands. Heuristic discovery, human-reviewable mapping, deterministic rename.</p>
      <div class="af-ctas">
        <a class="af-btn af-btn-primary" href="./quick-start">Get started</a>
        <a class="af-btn af-btn-ghost" href="./introduction">Read the manual</a>
        <a class="af-btn af-btn-ghost" href="https://github.com/Lzcorp-Solutions/acroforge">GitHub ↗</a>
      </div>
    </div>
    <div class="af-formcard" aria-hidden="true">
      <div class="af-formcard-head"><span>school_application.pdf</span><span>14 fields</span></div>
      <div class="af-formcard-field">
        <div class="af-formcard-rename"><s>page0_field6</s><span class="to">→ first_name</span></div>
        <div class="af-formcard-fill">Kofi</div>
      </div>
      <div class="af-formcard-field">
        <div class="af-formcard-rename"><s>untitled3</s><span class="to">→ surname</span></div>
        <div class="af-formcard-fill">Mensah</div>
      </div>
      <div class="af-formcard-field">
        <div class="af-formcard-rename"><s>page0_field9</s><span class="to">→ date_of_birth</span></div>
        <div class="af-formcard-fill">12 / 04 / 2011</div>
      </div>
    </div>
  </div>
</section>

<section class="af-section">
  <div class="af-section-inner">
    <h2 class="af-section-title">Small, focused commands. Each one <em>reviewable</em>.</h2>
    <p class="af-section-sub">Each command does one job and produces an artifact you can inspect before the next step touches the PDF. Pick the ones you need.</p>
    <div class="af-cmdrows">
      <div class="af-cmdrow">
        <span class="af-cmdrow-cmd">prepare</span>
        <span class="af-cmdrow-desc">Resolves PDF-internal name conflicts — multiple fields sharing one literal name — using the heuristic's proposals, so later stages never trip on ambiguity. Skips itself when there's nothing to resolve.</span>
        <span class="af-cmdrow-out">optional</span>
      </div>
      <div class="af-cmdrow">
        <span class="af-cmdrow-cmd">bootstrap</span>
        <span class="af-cmdrow-desc">Infers a starter schema and proposes a per-field mapping in one compile pass. The output is two YAML files you review and edit — nothing has touched the PDF yet.</span>
        <span class="af-cmdrow-out">→ schema.yml · mapping.yml</span>
      </div>
      <div class="af-cmdrow">
        <span class="af-cmdrow-cmd">annotate</span>
        <span class="af-cmdrow-desc">Renders a copy of the PDF with every field labeled inline, colour-coded against your mapping — green for confident, amber for review-needed. Open it next to your editor while you work.</span>
        <span class="af-cmdrow-out">→ annotated.pdf</span>
      </div>
      <div class="af-cmdrow">
        <span class="af-cmdrow-cmd">relabel apply</span>
        <span class="af-cmdrow-desc">Validates your edited mapping in full, then permanently rewrites the AcroForm field names. Collisions auto-disambiguate, and the PDF comes out programmatically fillable.</span>
        <span class="af-cmdrow-out">→ form.pdf, fixed</span>
      </div>
    </div>
  </div>
</section>

<section class="af-section af-section--band">
  <div class="af-section-inner">
    <h2 class="af-section-title af-section-title--right">What you <em>stop writing</em>.</h2>
    <p class="af-section-sub af-section-sub--right">Same PDF. Two starting points. One is a three-hour spelunk through <code>page0_fieldN</code> in a PDF viewer.</p>
    <div class="af-fragments">
      <div class="af-fragment af-fragment--before">
        <div class="af-fragment-label">What the vendor shipped</div>
        <div class="af-fragment-row"><span>page0_field6</span><span class="line"></span></div>
        <div class="af-fragment-row"><span>page0_field7</span><span class="line"></span></div>
        <div class="af-fragment-row"><span>untitled3</span><span class="line"></span></div>
        <div class="af-fragment-row"><span>Text-4</span><span class="line"></span></div>
        <div class="af-fragment-row"><span>page1_field2</span><span class="line"></span></div>
      </div>
      <div class="af-fragment af-fragment--after">
        <div class="af-fragment-label af-fragment-label--accent">After AcroForge</div>
        <div class="af-fragment-row"><span class="ok">first_name</span><span class="line"></span></div>
        <div class="af-fragment-row"><span class="ok">surname</span><span class="line"></span></div>
        <div class="af-fragment-row"><span class="ok">date_of_birth</span><span class="line"></span></div>
        <div class="af-fragment-row"><span class="warn">guardian_phone ?</span><span class="line"></span></div>
        <div class="af-fragment-row"><span class="ok">home_address</span><span class="line"></span></div>
        <div class="af-fragment-legend"><span class="ok">●</span> confident&ensp;<span class="warn">●</span> review-needed — the same colour-coding <code>annotate</code> draws on the PDF itself</div>
      </div>
    </div>
  </div>
</section>

<section class="af-section">
  <div class="af-section-inner">
    <h2 class="af-section-title">What the engine does <em>well</em>.</h2>
    <p class="af-section-sub">Discovery, review, rename, fill — plus the details that make those steps reliable on real-world PDFs.</p>
    <div class="af-index">
      <div class="af-index-entry af-index-entry--lead">
        <h3>Spatial label discovery</h3>
        <p>For each cryptic field, the engine scans surrounding text with mode-aware weighted scoring across Grid-Lock, Inline Paragraph, and Standard Label layouts. The label finds you.</p>
      </div>
      <div class="af-index-entry af-index-entry--lead">
        <h3>Human-readable artifacts</h3>
        <p>Every stage produces a YAML you can open in an editor. The mapping documents what was guessed, what was confident, and what you decided. Re-running propose preserves your edits.</p>
      </div>
      <div class="af-index-entry">
        <h3>Visual review</h3>
        <p><code>annotate</code> renders a copy of the PDF with each field labeled inline, colour-coded against your mapping — green for confident proposals, amber for review-needed, gray for missing. Open it next to your editor.</p>
      </div>
      <div class="af-index-entry">
        <h3>Duplicate-name resolution</h3>
        <p>Some PDFs ship with three fields all literally named <code>date</code>. <code>prepare</code> spots them and rewrites each to a unique heuristic-proposed name before the mapping is generated, so the YAML stays clean.</p>
      </div>
      <div class="af-index-entry">
        <h3>Unicode-clean labels</h3>
        <p>Ligatures (ﬁ ﬂ ﬀ), curly quotes, en/em dashes, zero-width chars: NFKC plus a small substitution table normalize every extracted label so grep, search, and your mapping reviews all work on plain ASCII.</p>
      </div>
      <div class="af-index-entry">
        <h3>Schema-driven, deterministic</h3>
        <p>Declare canonical fields once — the engine canonicalises vendor variations into one key set and the validator enforces type contracts. The whole mapping validates before anything touches the PDF, so it never half-renames.</p>
      </div>
    </div>
  </div>
</section>

<section class="af-section af-section--dark">
  <div class="af-section-inner">
    <h2 class="af-section-title">Shell or Ruby. <em>Same engine</em>.</h2>
    <p class="af-section-sub">The CLI is a thin shell over the public Ruby API. Choose the surface that fits your workflow.</p>
    <div class="af-two-col">
      <div class="af-two-col-card">
        <h3>Shell</h3>

```bash
# Resolve duplicate AcroForm field names, if any
acroforge prepare form.pdf

# Infer schema + propose mapping in one compile pass
acroforge bootstrap form.pdf

# Visual review: open annotated.pdf alongside mapping.yml
acroforge annotate form.pdf --mapping mapping.yml

# Apply your edited mapping to the PDF in place
acroforge relabel apply form.pdf mapping.yml
```

<a class="af-btn af-btn-ghost" href="./cli">CLI reference →</a>

</div>
      <div class="af-two-col-card">
        <h3>Ruby</h3>

```ruby
require "acroforge"

# Infer schema + propose mapping in one pass
schema = AcroForge::Schema.infer("form.pdf")
AcroForge::Schema.dump(schema, "schema.yml")

# Visual review file colour-coded against the mapping
AcroForge::Annotator.annotate("form.pdf",
  mapping: "mapping.yml", out: "annotated.pdf")

# Apply mapping in place after review
AcroForge::Relabeler.apply!("form.pdf", "mapping.yml")
```

<a class="af-btn af-btn-ghost" href="./api">Library API →</a>

</div>
    </div>
  </div>
</section>

<section class="af-section af-cta">
  <div class="af-section-inner af-cta-grid">
    <div>
      <h2>Stop hand-mapping <em>page0_field6</em>.</h2>
      <p>Add AcroForge to your Gemfile, then walk through the quick start. Five minutes to a fillable PDF.</p>
      <div class="af-ctas">
        <a class="af-btn af-btn-dark" href="./quick-start">Quick start</a>
        <a class="af-btn af-btn-light" href="https://github.com/Lzcorp-Solutions/acroforge">GitHub</a>
      </div>
    </div>
    <div class="af-stepper" aria-label="From install to fillable PDF in four steps">
      <div class="af-step">
        <span class="af-step-num">01</span>
        <div class="af-step-body">
          <div class="af-step-label">Add the gem</div>
          <div class="af-step-cmd">gem "acroforge"</div>
        </div>
      </div>
      <div class="af-step">
        <span class="af-step-num">02</span>
        <div class="af-step-body">
          <div class="af-step-label">Bootstrap</div>
          <div class="af-step-cmd">acroforge bootstrap form.pdf</div>
        </div>
      </div>
      <div class="af-step">
        <span class="af-step-num">03</span>
        <div class="af-step-body">
          <div class="af-step-label">Review the mapping</div>
          <div class="af-step-cmd">$EDITOR mapping.yml</div>
        </div>
      </div>
      <div class="af-step">
        <span class="af-step-num">04</span>
        <div class="af-step-body">
          <div class="af-step-label">Apply</div>
          <div class="af-step-cmd">acroforge relabel apply <span class="accent">→ fillable PDF</span></div>
        </div>
      </div>
    </div>
  </div>
</section>
