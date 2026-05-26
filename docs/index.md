---
layout: home
title: AcroForge: AcroForms, forged clean.
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
    <h2 class="af-section-title">Four steps. Each one <em>reviewable</em>.</h2>
    <p class="af-section-sub">Heuristics are wrong sometimes. The pipeline produces an artifact at each stage so you can correct the machine before it touches the PDF.</p>
    <div class="af-pipeline">
      <div class="af-step">
        <div class="af-step-num">01</div>
        <h3 class="af-step-name">Infer schema</h3>
        <span class="af-step-cmd">schema infer</span>
        <p class="af-step-desc">Heuristic walks the PDF and proposes a canonical schema of fields, types, and label variations.</p>
      </div>
      <div class="af-step">
        <div class="af-step-num">02</div>
        <h3 class="af-step-name">Propose mapping</h3>
        <span class="af-step-cmd">relabel propose</span>
        <p class="af-step-desc">One YAML row per field, sorted top-to-bottom. Override wrong guesses, leave the rest.</p>
      </div>
      <div class="af-step">
        <div class="af-step-num">03</div>
        <h3 class="af-step-name">Apply rename</h3>
        <span class="af-step-cmd">relabel apply</span>
        <p class="af-step-desc">Rewrites the AcroForm dictionary in place. Collisions auto-disambiguate. PDF is permanently usable.</p>
      </div>
      <div class="af-step">
        <div class="af-step-num">04</div>
        <h3 class="af-step-name">Fill</h3>
        <span class="af-step-cmd">Engine#fill!</span>
        <p class="af-step-desc">Pass a hash keyed by your semantic names. Validator enforces declared type contracts.</p>
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
<pre><span class="prompt">$</span> acroforge bootstrap form.pdf
<span class="prompt">$</span> <span class="dim">$EDITOR mapping.yml</span>
<span class="prompt">$</span> acroforge relabel apply form.pdf mapping.yml
<span class="ok">      done.</span></pre>
      </div>
    </div>
  </div>
</section>

<section class="af-section af-section--band">
  <div class="af-section-inner">
    <div class="af-section-num">03 / Capabilities</div>
    <h2 class="af-section-title">Three things the engine does <em>well</em>.</h2>
    <p class="af-section-sub">No icon-decorated feature grids. Just what AcroForge actually provides, plainly.</p>
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
        <h3 class="af-feature-name">Deterministic, schema-driven</h3>
        <p class="af-feature-desc">Declare canonical fields once. The engine canonicalises vendor variations into one key set. Validator enforces type contracts. apply! never half-renames a PDF.</p>
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
acroforge bootstrap form.pdf
acroforge schema infer form.pdf --out s.yml
acroforge relabel propose form.pdf \
  --schema s.yml --out m.yml
acroforge relabel apply form.pdf m.yml
acroforge compile form.pdf
```

<a class="af-btn af-btn-light" href="./cli">CLI reference →</a>

</div>
      <div class="af-two-col-card">
        <h3>Ruby</h3>

```ruby
require "acroforge"

schema = AcroForge::Schema.infer("form.pdf")
AcroForge::Schema.dump(schema, "s.yml")

AcroForge::Relabeler.propose("form.pdf",
  out: "m.yml", schema: schema)
AcroForge::Relabeler.apply!("form.pdf", "m.yml")

AcroForge::Engine.new("form.pdf",
  schema: schema).fill!(payload, "out.pdf")
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
