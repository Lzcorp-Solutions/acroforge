# frozen_string_literal: true

# Regenerable synthetic fixture PDFs for FormStencil specs.
# Run from the gem root: ruby spec/fixtures/build_fixtures.rb
#
# Produces four fixtures used across the spec suite:
#   - garbage_named.pdf      — AcroForm fields with non-semantic names (pageN_fieldM), 3 pages.
#   - semantic_named.pdf     — Same structure, fields named semantically, 3 pages.
#   - no_acroform.pdf        — Plain text page, no AcroForm dictionary.
#   - school_application.pdf — Semantic-named school admission form, 3 pages.

require "hexapdf"

FIXTURES_DIR = __dir__

def draw_section_header(canvas, text, y)
  canvas.font("Helvetica", size: 14, variant: :bold)
  canvas.text(text, at: [72, y])
end

def draw_field_label(canvas, text, x, y)
  canvas.font("Helvetica", size: 10)
  canvas.text(text, at: [x, y])
end

# Draws one field (label + widget) onto the page.
# spec keys:
#   :name, :label, :type, :label_pos (:left | :above), :y, :field_x, :label_x
#   :options  — array of {value:, text:} for :radio
#   :choices  — array of strings for :choice
def draw_field(canvas, page, form, spec)
  label_x = spec[:label_x]
  field_x = spec[:field_x]
  y = spec[:y]

  if spec[:label_pos] == :above
    draw_field_label(canvas, spec[:label], field_x, y + 22)
  else
    draw_field_label(canvas, spec[:label], label_x, y + 4)
  end

  case spec[:type]
  when :text
    field = form.create_text_field(spec[:name])
    field.create_widget(page, Rect: [field_x, y, field_x + 200, y + 18])

  when :radio
    rg = form.create_radio_button(spec[:name])
    spec[:options].each_with_index do |opt, i|
      xo = field_x + (i * 100)
      rg.create_widget(page, Rect: [xo, y, xo + 14, y + 14], value: opt[:value])
      draw_field_label(canvas, opt[:text], xo + 18, y + 2)
    end

  when :checkbox
    cb = form.create_check_box(spec[:name])
    cb.create_widget(page, Rect: [field_x, y, field_x + 14, y + 14])

  when :choice
    field = form.create_combo_box(spec[:name], option_items: spec[:choices])
    field.create_widget(page, Rect: [field_x, y, field_x + 200, y + 18])
  end
end

# Builds and writes one PDF from a pages_spec array.
# Each element: { header:, fields: [...] }
def build_pdf(pages_spec, out_path)
  doc = HexaPDF::Document.new
  form = doc.acro_form(create: true)
  total_fields = 0

  pages_spec.each do |page_spec|
    page = doc.pages.add
    canvas = page.canvas

    draw_section_header(canvas, page_spec[:header], 750)

    page_spec[:fields].each do |spec|
      draw_field(canvas, page, form, spec)
      total_fields += 1
    end
  end

  doc.write(out_path, validate: false)
  puts "Wrote #{out_path} (#{File.size(out_path)} bytes, #{total_fields} fields)"
end

# ---------------------------------------------------------------------------
# Loan — garbage_named.pdf
# Field names follow pageN_fieldM convention. Includes page0_field6 and
# page0_field28 which are referenced directly in Task 14's Relabeler specs.
# ---------------------------------------------------------------------------

LOAN_GARBAGE_PAGES = [
  {
    header: "Personal Details",
    fields: [
      {name: "page0_field6", label: "Full Name:", type: :text, y: 700, label_x: 72, field_x: 220, label_pos: :left},
      {name: "page0_field7", label: "Email Address:", type: :text, y: 670, label_x: 72, field_x: 220, label_pos: :left},
      {name: "page0_field8", label: "Phone Number:", type: :text, y: 640, label_x: 72, field_x: 220, label_pos: :left},
      {name: "page0_field9", label: "Date of Birth:", type: :text, y: 610, label_x: 72, field_x: 220, label_pos: :above},
      {
        name: "page0_field10",
        label: "Gender:",
        type: :radio,
        y: 575,
        label_x: 72,
        field_x: 220,
        label_pos: :left,
        options: [
          {value: :male, text: "Male"},
          {value: :female, text: "Female"}
        ]
      },
      {
        name: "page0_field11",
        label: "Marital Status:",
        type: :choice,
        y: 545,
        label_x: 72,
        field_x: 220,
        label_pos: :left,
        choices: %w[Single Married Divorced Widowed]
      },
      {name: "page0_field28", label: "Residential Address:", type: :text, y: 515, label_x: 72, field_x: 220, label_pos: :above}
    ]
  },
  {
    header: "Employment Details",
    fields: [
      {name: "page1_field0", label: "Employer Name:", type: :text, y: 700, label_x: 72, field_x: 220, label_pos: :left},
      {name: "page1_field1", label: "Occupation:", type: :text, y: 670, label_x: 72, field_x: 220, label_pos: :left},
      {name: "page1_field2", label: "Annual Salary:", type: :text, y: 640, label_x: 72, field_x: 220, label_pos: :above},
      {name: "page1_field3", label: "Date Employed:", type: :text, y: 610, label_x: 72, field_x: 220, label_pos: :left}
    ]
  },
  {
    header: "Loan Details",
    fields: [
      {name: "page2_field0", label: "Amount Requested:", type: :text, y: 700, label_x: 72, field_x: 220, label_pos: :left},
      {name: "page2_field1", label: "Loan Tenor (months):", type: :text, y: 670, label_x: 72, field_x: 220, label_pos: :left},
      {name: "page2_field2", label: "Purpose of Loan:", type: :text, y: 640, label_x: 72, field_x: 220, label_pos: :above},
      {
        name: "page2_field3",
        label: "Repayment Mode:",
        type: :radio,
        y: 605,
        label_x: 72,
        field_x: 220,
        label_pos: :left,
        options: [
          {value: :standing_order, text: "Standing Order"},
          {value: :direct_debit, text: "Direct Debit"}
        ]
      },
      {name: "page2_field4", label: "I confirm the information above is accurate", type: :checkbox, y: 575, label_x: 72, field_x: 72, label_pos: :above}
    ]
  }
].freeze

build_pdf(LOAN_GARBAGE_PAGES, File.join(FIXTURES_DIR, "garbage_named.pdf"))

# ---------------------------------------------------------------------------
# Loan — semantic_named.pdf
# Same structure, semantically-named fields.
# ---------------------------------------------------------------------------

LOAN_SEMANTIC_PAGES = [
  {
    header: "Personal Details",
    fields: [
      {name: "full_name", label: "Full Name:", type: :text, y: 700, label_x: 72, field_x: 220, label_pos: :left},
      {name: "email", label: "Email Address:", type: :text, y: 670, label_x: 72, field_x: 220, label_pos: :left},
      {name: "phone_number", label: "Phone Number:", type: :text, y: 640, label_x: 72, field_x: 220, label_pos: :left},
      {name: "date_of_birth", label: "Date of Birth:", type: :text, y: 610, label_x: 72, field_x: 220, label_pos: :above},
      {
        name: "gender",
        label: "Gender:",
        type: :radio,
        y: 575,
        label_x: 72,
        field_x: 220,
        label_pos: :left,
        options: [
          {value: :male, text: "Male"},
          {value: :female, text: "Female"}
        ]
      },
      {
        name: "marital_status",
        label: "Marital Status:",
        type: :choice,
        y: 545,
        label_x: 72,
        field_x: 220,
        label_pos: :left,
        choices: %w[Single Married Divorced Widowed]
      },
      {name: "residential_address", label: "Residential Address:", type: :text, y: 515, label_x: 72, field_x: 220, label_pos: :above}
    ]
  },
  {
    header: "Employment Details",
    fields: [
      {name: "employer_name", label: "Employer Name:", type: :text, y: 700, label_x: 72, field_x: 220, label_pos: :left},
      {name: "occupation", label: "Occupation:", type: :text, y: 670, label_x: 72, field_x: 220, label_pos: :left},
      {name: "annual_salary", label: "Annual Salary:", type: :text, y: 640, label_x: 72, field_x: 220, label_pos: :above},
      {name: "date_employed", label: "Date Employed:", type: :text, y: 610, label_x: 72, field_x: 220, label_pos: :left}
    ]
  },
  {
    header: "Loan Details",
    fields: [
      {name: "amount_requested", label: "Amount Requested:", type: :text, y: 700, label_x: 72, field_x: 220, label_pos: :left},
      {name: "loan_tenor", label: "Loan Tenor (months):", type: :text, y: 670, label_x: 72, field_x: 220, label_pos: :left},
      {name: "purpose_of_loan", label: "Purpose of Loan:", type: :text, y: 640, label_x: 72, field_x: 220, label_pos: :above},
      {
        name: "repayment_mode",
        label: "Repayment Mode:",
        type: :radio,
        y: 605,
        label_x: 72,
        field_x: 220,
        label_pos: :left,
        options: [
          {value: :standing_order, text: "Standing Order"},
          {value: :direct_debit, text: "Direct Debit"}
        ]
      },
      {name: "terms_accepted", label: "I confirm the information above is accurate", type: :checkbox, y: 575, label_x: 72, field_x: 72, label_pos: :above}
    ]
  }
].freeze

build_pdf(LOAN_SEMANTIC_PAGES, File.join(FIXTURES_DIR, "semantic_named.pdf"))

# ---------------------------------------------------------------------------
# no_acroform.pdf — plain text, no AcroForm dictionary
# ---------------------------------------------------------------------------

begin
  doc = HexaPDF::Document.new
  page = doc.pages.add
  canvas = page.canvas
  canvas.font("Helvetica", size: 12)
  canvas.text("This PDF intentionally has no AcroForm fields.", at: [72, 700])
  canvas.text("It exists for testing the engine's no-form code path.", at: [72, 680])

  out = File.join(FIXTURES_DIR, "no_acroform.pdf")
  doc.write(out, validate: false)
  puts "Wrote #{out} (#{File.size(out)} bytes, no AcroForm)"
end

# ---------------------------------------------------------------------------
# school_application.pdf — semantic-named school admission form, 3 pages
# ---------------------------------------------------------------------------

SCHOOL_PAGES = [
  {
    header: "Student Information",
    fields: [
      {name: "student_full_name", label: "Student Full Name:", type: :text, y: 700, label_x: 72, field_x: 220, label_pos: :left},
      {name: "date_of_birth", label: "Date of Birth:", type: :text, y: 670, label_x: 72, field_x: 220, label_pos: :left},
      {
        name: "gender",
        label: "Gender:",
        type: :radio,
        y: 635,
        label_x: 72,
        field_x: 220,
        label_pos: :left,
        options: [
          {value: :male, text: "Male"},
          {value: :female, text: "Female"}
        ]
      },
      {
        name: "grade_applying_for",
        label: "Grade Applying For:",
        type: :choice,
        y: 605,
        label_x: 72,
        field_x: 220,
        label_pos: :left,
        choices: %w[Pre-K Kindergarten Grade-1 Grade-2 Grade-3 Grade-4 Grade-5]
      },
      {name: "home_address", label: "Home Address:", type: :text, y: 575, label_x: 72, field_x: 220, label_pos: :above}
    ]
  },
  {
    header: "Parent/Guardian",
    fields: [
      {name: "parent_full_name", label: "Parent/Guardian Full Name:", type: :text, y: 700, label_x: 72, field_x: 280, label_pos: :left},
      {
        name: "relationship",
        label: "Relationship:",
        type: :choice,
        y: 670,
        label_x: 72,
        field_x: 220,
        label_pos: :left,
        choices: %w[Mother Father Guardian]
      },
      {name: "parent_email", label: "Email:", type: :text, y: 640, label_x: 72, field_x: 220, label_pos: :left},
      {name: "parent_phone", label: "Phone:", type: :text, y: 610, label_x: 72, field_x: 220, label_pos: :above},
      {name: "parent_occupation", label: "Occupation:", type: :text, y: 580, label_x: 72, field_x: 220, label_pos: :left}
    ]
  },
  {
    header: "Previous School & Enrollment",
    fields: [
      {name: "previous_school_name", label: "Previous School:", type: :text, y: 700, label_x: 72, field_x: 220, label_pos: :left},
      {name: "last_grade_completed", label: "Last Grade Completed:", type: :text, y: 670, label_x: 72, field_x: 220, label_pos: :left},
      {name: "transfer_reason", label: "Reason for Transfer:", type: :text, y: 640, label_x: 72, field_x: 220, label_pos: :above},
      {
        name: "program_preference",
        label: "Program Preference:",
        type: :radio,
        y: 605,
        label_x: 72,
        field_x: 220,
        label_pos: :left,
        options: [
          {value: :day, text: "Day"},
          {value: :boarding, text: "Boarding"}
        ]
      },
      {name: "consent_to_share_records", label: "I consent to share academic records", type: :checkbox, y: 575, label_x: 72, field_x: 72, label_pos: :above}
    ]
  }
].freeze

build_pdf(SCHOOL_PAGES, File.join(FIXTURES_DIR, "school_application.pdf"))
