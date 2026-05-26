# frozen_string_literal: true

# Regenerable synthetic fixture PDFs for FormStencil specs.
# Run from the gem root: ruby spec/fixtures/build_fixtures.rb
#
# Produces three fixtures used across the spec suite:
#   - garbage_named.pdf   — AcroForm fields with non-semantic names (page0_fieldX) next to visible labels.
#   - semantic_named.pdf  — AcroForm fields already named semantically (full_name, email, ...).
#   - no_acroform.pdf     — plain text page, no AcroForm dictionary.
#
# Field names and labels here are deliberately generic — no proprietary vendor content.

require "hexapdf"

FIXTURES_DIR = __dir__

def draw_label(canvas, text, x, y)
  canvas.font("Helvetica", size: 10)
  canvas.text(text, at: [x, y])
end

def build_form_pdf(field_specs)
  doc = HexaPDF::Document.new
  fields_by_page = field_specs.group_by { |s| s[:page] }
  max_page = fields_by_page.keys.max || 0

  pages = (0..max_page).map { doc.pages.add }
  form = doc.acro_form(create: true)

  fields_by_page.each do |page_idx, specs|
    page = pages[page_idx]
    canvas = page.canvas

    specs.each do |s|
      draw_label(canvas, s[:label], s[:label_x], s[:y] + 4)

      case s[:type]
      when :text
        field = form.create_text_field(s[:name])
        field.create_widget(page, Rect: [s[:field_x], s[:y], s[:field_x] + 200, s[:y] + 18])
      when :radio
        rg = form.create_radio_button(s[:name])
        s[:options].each_with_index do |opt, i|
          xo = s[:field_x] + (i * 80)
          rg.create_widget(page, Rect: [xo, s[:y], xo + 14, s[:y] + 14], value: opt.to_sym)
          draw_label(canvas, opt.to_s, xo + 18, s[:y] + 4)
        end
      end
    end
  end

  doc
end

# ---- garbage_named.pdf ----
# 15 fields with page0_fieldX names. Includes page0_field6 and page0_field28 (used directly in Relabeler specs).

garbage_specs = [
  {name: "page0_field6", label: "Full Name:", type: :text, page: 0, y: 700, label_x: 72, field_x: 220},
  {name: "page0_field7", label: "Email Address:", type: :text, page: 0, y: 670, label_x: 72, field_x: 220},
  {name: "page0_field8", label: "Phone Number:", type: :text, page: 0, y: 640, label_x: 72, field_x: 220},
  {name: "page0_field9", label: "Date of Birth:", type: :text, page: 0, y: 610, label_x: 72, field_x: 220},
  {name: "page0_field10", label: "Gender:", type: :radio, page: 0, y: 580, label_x: 72, field_x: 220, options: %w[Male Female]},
  {name: "page0_field11", label: "Residential Address:", type: :text, page: 0, y: 550, label_x: 72, field_x: 220},
  {name: "page0_field12", label: "City:", type: :text, page: 0, y: 520, label_x: 72, field_x: 220},
  {name: "page0_field13", label: "Postal Code:", type: :text, page: 0, y: 490, label_x: 72, field_x: 220},
  {name: "page0_field28", label: "Applicant Name:", type: :text, page: 0, y: 440, label_x: 72, field_x: 220},
  {name: "page0_field29", label: "Amount Requested:", type: :text, page: 0, y: 410, label_x: 72, field_x: 220},
  {name: "page0_field30", label: "Loan Tenor (months):", type: :text, page: 0, y: 380, label_x: 72, field_x: 220},
  {name: "page0_field31", label: "Purpose of Loan:", type: :text, page: 0, y: 350, label_x: 72, field_x: 220},
  {name: "page0_field32", label: "Annual Salary:", type: :text, page: 0, y: 320, label_x: 72, field_x: 220},
  {name: "page0_field33", label: "Occupation:", type: :text, page: 0, y: 290, label_x: 72, field_x: 220},
  {name: "page0_field34", label: "Employer Name:", type: :text, page: 0, y: 260, label_x: 72, field_x: 220}
]

out = File.join(FIXTURES_DIR, "garbage_named.pdf")
build_form_pdf(garbage_specs).write(out, validate: false)
puts "Wrote #{out} (#{File.size(out)} bytes, #{garbage_specs.size} fields)"

# ---- semantic_named.pdf ----
# Same layout, but AcroForm field names are already semantic.

semantic_specs = [
  {name: "full_name", label: "Full Name:", type: :text, page: 0, y: 700, label_x: 72, field_x: 220},
  {name: "email", label: "Email Address:", type: :text, page: 0, y: 670, label_x: 72, field_x: 220},
  {name: "phone_number", label: "Phone Number:", type: :text, page: 0, y: 640, label_x: 72, field_x: 220},
  {name: "date_of_birth", label: "Date of Birth:", type: :text, page: 0, y: 610, label_x: 72, field_x: 220},
  {name: "gender", label: "Gender:", type: :radio, page: 0, y: 580, label_x: 72, field_x: 220, options: %w[Male Female]},
  {name: "residential_address", label: "Residential Address:", type: :text, page: 0, y: 550, label_x: 72, field_x: 220},
  {name: "city", label: "City:", type: :text, page: 0, y: 520, label_x: 72, field_x: 220},
  {name: "amount_requested", label: "Amount Requested:", type: :text, page: 0, y: 440, label_x: 72, field_x: 220},
  {name: "loan_tenor", label: "Loan Tenor (months):", type: :text, page: 0, y: 410, label_x: 72, field_x: 220},
  {name: "purpose_of_loan", label: "Purpose of Loan:", type: :text, page: 0, y: 380, label_x: 72, field_x: 220},
  {name: "annual_salary", label: "Annual Salary:", type: :text, page: 0, y: 350, label_x: 72, field_x: 220},
  {name: "occupation", label: "Occupation:", type: :text, page: 0, y: 320, label_x: 72, field_x: 220},
  {name: "employer_name", label: "Employer Name:", type: :text, page: 0, y: 290, label_x: 72, field_x: 220}
]

out = File.join(FIXTURES_DIR, "semantic_named.pdf")
build_form_pdf(semantic_specs).write(out, validate: false)
puts "Wrote #{out} (#{File.size(out)} bytes, #{semantic_specs.size} fields)"

# ---- no_acroform.pdf ----

doc = HexaPDF::Document.new
page = doc.pages.add
canvas = page.canvas
canvas.font("Helvetica", size: 12)
canvas.text("This PDF intentionally has no AcroForm fields.", at: [72, 700])
canvas.text("It exists for testing the engine's no-form code path.", at: [72, 680])

out = File.join(FIXTURES_DIR, "no_acroform.pdf")
doc.write(out, validate: false)
puts "Wrote #{out} (#{File.size(out)} bytes, no AcroForm)"
