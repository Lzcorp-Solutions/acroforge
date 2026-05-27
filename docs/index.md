---
layout: home
title: "AcroForge: AcroForms, forged clean."
titleTemplate: false
---

<section class="af-section af-section--dark af-hero">
  <div class="af-section-inner af-hero-grid">
    <div>
      <div class="af-eyebrow"><span class="em">AcroForge</span><span class="sep">/</span>Ruby PDF toolkit<span class="sep">/</span>v0.1.0</div>
      <h1 class="af-headline">AcroForms,<br /><em>forged clean.</em></h1>
      <p class="af-lede">Take a broken-named PDF form and make it programmatically fillable in three commands. Heuristic discovery, human-reviewable mapping, deterministic rename.</p>
      <div class="af-ctas">
        <a class="af-btn af-btn-primary" href="./quick-start">Get started</a>
        <a class="af-btn af-btn-ghost" href="./introduction">Read the manual</a>
        <a class="af-btn af-btn-ghost" href="https://github.com/Lzcorp-Solutions/acroforge">GitHub ↗</a>
      </div>
    </div>
<pre class="af-term"><span class="prompt">$</span> acroforge bootstrap form.pdf
<span class="dim">      schema.yml   14 entries</span>
<span class="dim">      mapping.yml  98 entries</span>
<span class="prompt">$</span> <span class="dim">$EDITOR mapping.yml</span>
<span class="prompt">$</span> acroforge relabel apply form.pdf mapping.yml
<span class="dim">      96 renamed</span>
<span class="dim">      2  disambiguated</span>
<span class="prompt">$</span> <span class="cursor"></span></pre>
  </div>
</section>

<section class="af-section af-section--band">
  <div class="af-section-inner">
    <div class="af-section-num">01 / Pipeline</div>
    <h2 class="af-section-title">Small, focused commands. Each one <em>reviewable</em>.</h2>
    <p class="af-section-sub">Each command does one job and produces an artifact you can inspect before the next step touches the PDF. Pick the ones you need.</p>
    <div class="af-pipeline">
      <div class="af-step">
        <div class="af-step-num">01</div>
        <h3 class="af-step-name">Prepare</h3>
        <span class="af-step-cmd">prepare</span>
        <p class="af-step-desc">Resolves PDF-internal conflicts (multiple fields sharing one name) using the heuristic's proposals. Optional: skips itself when there's nothing to resolve.</p>
      </div>
      <div class="af-step">
        <div class="af-step-num">02</div>
        <h3 class="af-step-name">Bootstrap</h3>
        <span class="af-step-cmd">bootstrap</span>
        <p class="af-step-desc">Infers a starter schema and proposes a per-field mapping in one compile pass. Output is two YAML files you review.</p>
      </div>
      <div class="af-step">
        <div class="af-step-num">03</div>
        <h3 class="af-step-name">Annotate</h3>
        <span class="af-step-cmd">annotate</span>
        <p class="af-step-desc">Renders a copy of the PDF with each field labeled inline, colour-coded against the mapping. Visual reference while you edit.</p>
      </div>
      <div class="af-step">
        <div class="af-step-num">04</div>
        <h3 class="af-step-name">Apply</h3>
        <span class="af-step-cmd">relabel apply</span>
        <p class="af-step-desc">Reads your edited mapping and permanently rewrites the AcroForm field names. Collisions auto-disambiguate. PDF is now usable.</p>
      </div>
    </div>
  </div>
</section>

<section class="af-section">
  <div class="af-section-inner">
    <div class="af-section-num">02 / Before / After</div>
    <h2 class="af-section-title">What you <em>stop writing</em>.</h2>
    <p class="af-section-sub">Same PDF. Two starting points. One is a three-hour spelunk through <code>page0_fieldN</code> in a PDF viewer.</p>
    <div class="af-compare">
      <div class="af-compare-card">
        <span class="af-compare-label">Without AcroForge</span>
<pre><span class="prompt">$</span> ruby fill_form.rb
<span class="dim"># open PDF in a viewer</span>
<span class="dim"># click each of 98 fields</span>
<span class="dim"># note position → meaning</span>
<span class="dim"># transcribe to ruby hash</span>
<span class="dim"># repeat per vendor</span></pre>
      </div>
      <div class="af-compare-card">
        <span class="af-compare-label af-compare-label--good">With AcroForge</span>
<pre><span class="prompt">$</span> acroforge prepare form.pdf
<span class="prompt">$</span> acroforge bootstrap form.pdf
<span class="prompt">$</span> acroforge annotate form.pdf <span class="dim">--mapping mapping.yml</span>
<span class="prompt">$</span> <span class="dim">$EDITOR mapping.yml</span>  <span class="dim"># reviewing against annotated.pdf</span>
<span class="prompt">$</span> acroforge relabel apply form.pdf mapping.yml
<span class="ok">      done.</span></pre>
      </div>
    </div>
  </div>
</section>

<section class="af-section af-section--band">
  <div class="af-section-inner">
    <div class="af-section-num">03 / Capabilities</div>
    <h2 class="af-section-title">What the engine does <em>well</em>.</h2>
    <p class="af-section-sub">Discovery, review, rename, fill, plus the details that make those steps reliable on real-world PDFs.</p>
    <div class="af-features">
      <div class="af-feature">
        <div class="af-feature-num">01</div>
        <h3 class="af-feature-name">Spatial label discovery</h3>
        <p class="af-feature-desc">For each cryptic field, the engine scans surrounding text with mode-aware weighted scoring across Grid-Lock, Inline Paragraph, and Standard Label layouts. The label finds you.</p>
      </div>
      <div class="af-feature">
        <div class="af-feature-num">02</div>
        <h3 class="af-feature-name">Human-readable artifacts</h3>
        <p class="af-feature-desc">Every stage produces a YAML you can open in an editor. The mapping documents what was guessed, what was confident, and what you decided. Re-running propose preserves your edits.</p>
      </div>
      <div class="af-feature">
        <div class="af-feature-num">03</div>
        <h3 class="af-feature-name">Visual review</h3>
        <p class="af-feature-desc"><code>annotate</code> renders a copy of the PDF with each field labeled inline, colour-coded against your mapping. Green for confident proposals, amber for review-needed, gray for missing. Open it next to your editor.</p>
      </div>
      <div class="af-feature">
        <div class="af-feature-num">04</div>
        <h3 class="af-feature-name">Duplicate-name resolution</h3>
        <p class="af-feature-desc">Some PDFs ship with three fields all literally named <code>date</code>. <code>prepare</code> spots them and rewrites each to a unique heuristic-proposed name before the mapping is generated, so the YAML stays clean.</p>
      </div>
      <div class="af-feature">
        <div class="af-feature-num">05</div>
        <h3 class="af-feature-name">Unicode-clean labels</h3>
        <p class="af-feature-desc">Ligatures (ﬁ ﬂ ﬀ), curly quotes, en/em dashes, zero-width chars: NFKC plus a small substitution table normalize every extracted label so grep, search, and your mapping reviews all work on plain ASCII.</p>
      </div>
      <div class="af-feature">
        <div class="af-feature-num">06</div>
        <h3 class="af-feature-name">Schema-driven, deterministic</h3>
        <p class="af-feature-desc">Declare canonical fields once. The engine canonicalises vendor variations into one key set. Validator enforces type contracts. <code>apply!</code> validates the whole mapping before touching the PDF, so it never half-renames anything.</p>
      </div>
    </div>
  </div>
</section>

<section class="af-section">
  <div class="af-section-inner">
    <div class="af-section-num">04 / Surface</div>
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

<a class="af-btn af-btn-light" href="./cli">CLI reference →</a>

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

<a class="af-btn af-btn-light" href="./api">Library API →</a>

</div>
    </div>
  </div>
</section>

<section class="af-section af-cta">
  <div class="af-section-inner">
    <h2>Stop hand-mapping <em>page0_field6</em>.</h2>
    <p>Add AcroForge to your Gemfile, then walk through the quick start. Five minutes to a fillable PDF.</p>
    <div class="af-ctas">
      <a class="af-btn af-btn-dark" href="./quick-start">Quick start</a>
      <a class="af-btn af-btn-light" href="https://github.com/Lzcorp-Solutions/acroforge">GitHub</a>
    </div>
  </div>
</section>
