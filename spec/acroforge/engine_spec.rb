# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "acroforge"

RSpec.describe AcroForge::Engine do
  let(:semantic_fixture) { File.expand_path("../fixtures/semantic_named.pdf", __dir__) }

  around do |example|
    Dir.mktmpdir do |tmp|
      @tmp = tmp
      example.run
    end
  end

  describe "#compile! with no schema" do
    it "returns a result hash with the documented keys" do
      engine = described_class.new(semantic_fixture, normalized_dir: @tmp)
      result = silence_stdout { engine.compile! }

      expect(result.keys).to match_array(%i[mapped unmapped select_options new_fields_detected])
      expect(result[:mapped]).to be_a(Hash)
      expect(result[:mapped]).not_to be_empty
    end
  end

  let(:no_acroform_fixture) { File.expand_path("../fixtures/no_acroform.pdf", __dir__) }
  let(:garbage_fixture) { File.expand_path("../fixtures/garbage_named.pdf", __dir__) }

  describe "#compile! with an explicit schema" do
    it "canonicalizes labels into schema keys" do
      schema = {
        last_name: ["Last Name", "Surname"],
        date_of_birth: ["Date of Birth", "DOB"]
      }
      engine = described_class.new(semantic_fixture, schema: schema, normalized_dir: @tmp)
      result = silence_stdout { engine.compile! }

      mapped_values = result[:mapped].values.map(&:to_s)
      expect(mapped_values.any? { |v| v.include?("last_name") }).to be true
    end
  end

  describe "#compile! on a PDF without an AcroForm" do
    it "returns empty mapped/unmapped sets" do
      engine = described_class.new(no_acroform_fixture, normalized_dir: @tmp)
      result = silence_stdout { engine.compile! }
      expect(result[:mapped]).to be_empty
      expect(result[:unmapped]).to be_empty
    end
  end

  describe "#compile! on a PDF with garbage names and no overrides" do
    it "returns proposals from the spatial heuristic (non-empty mapped)" do
      engine = described_class.new(garbage_fixture, normalized_dir: @tmp)
      result = silence_stdout { engine.compile! }
      expect(result[:mapped]).not_to be_empty
    end
  end

  describe "#field_proposals" do
    it "returns one entry per AcroForm field with proposal metadata" do
      engine = described_class.new(garbage_fixture, normalized_dir: @tmp)
      silence_stdout { engine.compile! }

      proposals = engine.field_proposals
      expect(proposals).to be_an(Array)
      expect(proposals).not_to be_empty

      first = proposals.first
      expect(first).to include(
        :pdf_field_name,
        :pdf_field_type,
        :canonical_key,
        :raw_label,
        :confidence,
        :section,
        :page,
        :y,
        :x
      )
      expect(%i[text button choice other]).to include(first[:pdf_field_type])
      expect(%i[high medium low none]).to include(first[:confidence])
    end

    it "raises if called before compile!" do
      engine = described_class.new(garbage_fixture, normalized_dir: @tmp)
      expect { engine.field_proposals }.to raise_error(/compile/)
    end
  end

  describe "#validate_payload!" do
    it "raises ValidationError when a money field receives non-numeric input" do
      overrides = {amount_requested: {type: :money}}
      engine = described_class.new(semantic_fixture, overrides: overrides, normalized_dir: @tmp)
      silence_stdout { engine.compile! }

      expect {
        engine.validate_payload!({amount_requested: "not a number"})
      }.to raise_error(AcroForge::ValidationError)
    end
  end

  describe "#compile! button-field key shape" do
    it "uses the bare canonical key for button fields — no `_btn` suffix" do
      overrides = {
        "page0_field10" => {key: :gender, type: :select}
      }
      engine = described_class.new(garbage_fixture, overrides: overrides, normalized_dir: @tmp)
      result = silence_stdout { engine.compile! }

      values = result[:mapped].values.map(&:to_s)
      expect(values).to include("gender")
      expect(values.grep(/_btn/)).to be_empty
    end
  end

  describe "#compile! choice-field mapping" do
    it "auto-maps a choice field from its nearby label and persists its options" do
      engine = described_class.new(garbage_fixture, normalized_dir: @tmp)
      result = silence_stdout { engine.compile! }

      expect(result[:mapped].values.map(&:to_s)).to include("marital_status")
      expect(result[:select_options]["marital_status"]).to include("single" => "Single", "married" => "Married")
      expect(result[:unmapped]).not_to include("page0_field11")
    end
  end

  describe ".field_index" do
    # Build a tiny PDF in-memory with three fields all named "date" to
    # verify the synthetic naming scheme.
    it "disambiguates duplicate field names with #N suffixes" do
      doc = HexaPDF::Document.new
      page = doc.pages.add
      form = doc.acro_form(create: true)
      3.times do |i|
        field = form.create_text_field("date")
        field.create_widget(page, Rect: [100, 700 - (i * 20), 200, 715 - (i * 20)])
      end

      index = described_class.field_index(form)

      expect(index.keys).to contain_exactly("date", "date#1", "date#2")
      # All three keys should resolve to distinct field objects
      expect(index.values.uniq.length).to eq(3)
    end

    it "leaves uniquely-named fields with their bare name" do
      doc = HexaPDF::Document.new
      page = doc.pages.add
      form = doc.acro_form(create: true)
      form.create_text_field("full_name").create_widget(page, Rect: [0, 0, 100, 20])
      form.create_text_field("email").create_widget(page, Rect: [0, 30, 100, 50])

      index = described_class.field_index(form)
      expect(index.keys).to contain_exactly("full_name", "email")
    end
  end

  describe "#normalize_button_base_key" do
    let(:engine) { described_class.new(semantic_fixture, normalized_dir: @tmp) }

    it "overrides the spatial label and returns a canonical Title label when options look like a title selector" do
      options_map = {"dr" => "Dr", "mr" => "Mr", "mrs" => "Mrs", "miss" => "Miss"}
      key, label = engine.send(:normalize_button_base_key, :first_name, options_map)
      expect(key).to eq(:title)
      expect(label).to eq("Title")
    end

    it "overrides to :gender when options are male/female" do
      options_map = {"male" => "Male", "female" => "Female"}
      key, label = engine.send(:normalize_button_base_key, :ecowas_id, options_map)
      expect(key).to eq(:gender)
      expect(label).to eq("Gender")
    end

    it "returns the original base_key and nil label when options do not match a known set" do
      options_map = {"north" => "N", "south" => "S"}
      key, label = engine.send(:normalize_button_base_key, :direction, options_map)
      expect(key).to eq(:direction)
      expect(label).to be_nil
    end
  end

  describe "#fields / #field_names / #any_fields?" do
    it "returns one entry per AcroForm field with name, type, and alternate_name" do
      engine = described_class.new(semantic_fixture, normalized_dir: @tmp)
      fields = engine.fields
      expect(fields).not_to be_empty
      expect(fields.first).to include(:name, :type, :alternate_name)
      expect(fields.map { |f| f[:type] }.uniq - %i[text button choice other]).to be_empty
    end

    it "field_names returns just the names in document order" do
      engine = described_class.new(semantic_fixture, normalized_dir: @tmp)
      expect(engine.field_names).to eq(engine.fields.map { |f| f[:name] })
    end

    it "any_fields? is true for an AcroForm PDF and false for one without" do
      expect(described_class.new(semantic_fixture, normalized_dir: @tmp).any_fields?).to be true
      expect(described_class.new(no_acroform_fixture, normalized_dir: @tmp).any_fields?).to be false
    end

    it "decodes a JSON options map persisted in /TU into a Hash" do
      pdf_path = File.join(@tmp, "options_map.pdf")
      doc = HexaPDF::Document.new
      page = doc.pages.add
      form = doc.acro_form(create: true)
      title = form.create_radio_button("title")
      title.create_widget(page, Rect: [0, 0, 12, 12], value: :"0")
      title.create_widget(page, Rect: [20, 0, 32, 12], value: :"1")
      # What compile! persists for button/choice fields (engine.rb: field[:TU] = options_map.to_json).
      title[:TU] = {"dr" => "0", "mrs" => "1"}.to_json
      doc.write(pdf_path)

      fields = described_class.new(pdf_path, normalized_dir: @tmp).fields
      expect(fields.first[:alternate_name]).to eq({dr: "0", mrs: "1"})
    end

    it "leaves a plain-text /TU alternate name as a String" do
      pdf_path = File.join(@tmp, "tooltip.pdf")
      doc = HexaPDF::Document.new
      page = doc.pages.add
      form = doc.acro_form(create: true)
      field = form.create_text_field("last_name")
      field.create_widget(page, Rect: [0, 0, 100, 20])
      field[:TU] = "Your family name"
      doc.write(pdf_path)

      fields = described_class.new(pdf_path, normalized_dir: @tmp).fields
      expect(fields.first[:alternate_name]).to eq("Your family name")
    end

    it "leaves a missing /TU as nil" do
      fields = described_class.new(semantic_fixture, normalized_dir: @tmp).fields
      expect(fields.map { |f| f[:alternate_name] }.uniq).to eq([nil])
    end
  end

  describe "options-map round trip (compile! → fields → fill!)" do
    it "discovers radio options, persists them to /TU, and resolves payload values through them" do
      engine = described_class.new(garbage_fixture, normalized_dir: @tmp)
      result = silence_stdout { engine.compile! }

      expect(result[:select_options]["gender"]).to include("male" => "male", "female" => "female")

      normalized = described_class.new(engine.normalized_path, normalized_dir: @tmp)
      gender = normalized.fields.find { |f| f[:name] == "gender" }
      expect(gender[:alternate_name]).to eq({male: "male", female: "female"})

      out = File.join(@tmp, "filled.pdf")
      silence_stdout { normalized.fill!({gender: "Female"}, out) }

      doc = HexaPDF::Document.open(out)
      field = doc.acro_form.each_field.find { |f| f.full_field_name == "gender" }
      on_widget = field.each_widget.find { |w| w[:AP][:N].value.key?(:female) }
      expect(on_widget[:AS]).to eq(:female)
    end
  end

  describe "#fill! is standalone (no compile! required)" do
    it "fills the original template directly without ever calling compile!" do
      engine = described_class.new(semantic_fixture, normalized_dir: @tmp)
      out = File.join(@tmp, "out.pdf")

      result = silence_stdout { engine.fill!({last_name: "Alice"}, out) }

      expect(result[:filled].keys).to include(:last_name)
      expect(result[:missing]).to be_empty
      expect(File.exist?(out)).to be true
    end

    it "fills the source template even when a stale normalized PDF exists" do
      # An older compile! could leave a normalized file lying around with
      # different content; fill! must NOT silently consume it.
      stale = File.join(File.dirname(semantic_fixture), "semantic_named_normalized.pdf")
      File.write(stale, "definitely not a real pdf")
      begin
        engine = described_class.new(semantic_fixture, normalized_dir: File.dirname(semantic_fixture))
        out = File.join(@tmp, "out.pdf")
        expect { silence_stdout { engine.fill!({last_name: "Alice"}, out) } }.not_to raise_error
      ensure
        File.delete(stale) if File.exist?(stale)
      end
    end
  end

  describe "#fill! radio handling" do
    # Inline radio fixture with proper export values — the shared
    # semantic_named.pdf radios have empty allowed_values.
    def radio_pdf(path)
      doc = HexaPDF::Document.new
      page = doc.pages.add
      form = doc.acro_form(create: true)
      gender = form.create_radio_button("gender")
      gender.create_widget(page, Rect: [0, 0, 12, 12], value: :male)
      gender.create_widget(page, Rect: [20, 0, 32, 12], value: :female)
      doc.write(path)
      path
    end

    it "matches radio values case-insensitively against allowed_values" do
      pdf = radio_pdf(File.join(@tmp, "radio.pdf"))
      out = File.join(@tmp, "out.pdf")

      result = silence_stdout { described_class.new(pdf, normalized_dir: @tmp).fill!({gender: "MALE"}, out) }

      expect(result[:filled][:gender]).to eq("MALE")
      doc = HexaPDF::Document.open(out)
      gender = doc.acro_form.each_field.find { |f| f.full_field_name == "gender" }
      expect(gender.field_value).to eq(:male)
    end

    it "raises when a radio value matches no allowed option" do
      pdf = radio_pdf(File.join(@tmp, "radio.pdf"))
      out = File.join(@tmp, "out.pdf")

      expect {
        silence_stdout { described_class.new(pdf, normalized_dir: @tmp).fill!({gender: "alien"}, out) }
      }.to raise_error(AcroForge::Error, /gender rejected/)
    end
  end

  describe "#compile! preserve cascade" do
    it "(C) heuristic: keeps clean snake_case names verbatim with no schema" do
      engine = described_class.new(semantic_fixture, normalized_dir: @tmp)
      silence_stdout { engine.compile! }

      preserved = engine.field_proposals.select { |p| p[:confidence] == :preserved }
      expect(preserved).not_to be_empty
      preserved.each { |p| expect(p[:canonical_key].to_s).to eq(p[:pdf_field_name]) }
    end

    it "(B) schema match: keeps the field name when the schema has that key" do
      schema = {last_name: {type: :string, variations: []}}
      engine = described_class.new(semantic_fixture, schema: schema, normalized_dir: @tmp)
      silence_stdout { engine.compile! }

      entry = engine.field_proposals.find { |p| p[:pdf_field_name] == "last_name" }
      expect(entry[:canonical_key]).to eq(:last_name)
      expect(entry[:confidence]).to eq(:preserved)
    end

    it "(A) explicit: keeps a name on the preserve list even if it's a garbage marker" do
      engine = described_class.new(garbage_fixture, preserve: ["page0_field6"], normalized_dir: @tmp)
      silence_stdout { engine.compile! }

      entry = engine.field_proposals.find { |p| p[:pdf_field_name] == "page0_field6" }
      expect(entry[:canonical_key]).to eq(:page0_field6)
      expect(entry[:confidence]).to eq(:preserved)
    end

    it "populates @select_field_options for preserved choice fields" do
      engine = described_class.new(semantic_fixture, normalized_dir: @tmp)
      silence_stdout { engine.compile! }

      expect(engine.select_field_options["marital_status"])
        .to include("Single" => "Single", "Married" => "Married")
    end
  end

  describe "#looks_like_clean_identifier?" do
    let(:engine) { described_class.new(semantic_fixture, normalized_dir: @tmp) }

    it "accepts lowercase snake_case identifiers" do
      %w[first_name application_no social_security email mobile_no1].each do |n|
        expect(engine.send(:looks_like_clean_identifier?, n)).to be(true), "expected #{n.inspect} accepted"
      end
    end

    it "rejects auto-generated garbage marker names" do
      %w[page0_field6 text101 image80_af_image field42_text7].each do |n|
        expect(engine.send(:looks_like_clean_identifier?, n)).to be(false), "expected #{n.inspect} rejected"
      end
    end

    it "rejects names with uppercase letters, spaces, or punctuation" do
      ["First Name", "FirstName", "first-name", "first.name", "first name"].each do |n|
        expect(engine.send(:looks_like_clean_identifier?, n)).to be(false), "expected #{n.inspect} rejected"
      end
    end
  end

  describe "#canonical_schema_key_for (variations consumer)" do
    let(:engine) { described_class.new(semantic_fixture, normalized_dir: @tmp) }

    it "returns the canonical key when the label sanitizes directly to it" do
      engine.instance_variable_set(:@schema, {full_name: {type: :string, variations: []}})
      expect(engine.send(:canonical_schema_key_for, :full_name, "Full Name")).to eq(:full_name)
    end

    it "returns the canonical key when the label matches one of the variations" do
      engine.instance_variable_set(:@schema, {
        full_name: {type: :string, variations: ["Customer Name", "Applicant Full Name"]}
      })
      expect(engine.send(:canonical_schema_key_for, :customer_name, "Customer Name")).to eq(:full_name)
      expect(engine.send(:canonical_schema_key_for, :applicant_full_name, "Applicant Full Name")).to eq(:full_name)
    end

    it "returns nil when neither the base_key nor any variation matches" do
      engine.instance_variable_set(:@schema, {full_name: {type: :string, variations: ["Full Name"]}})
      expect(engine.send(:canonical_schema_key_for, :random_label, "Random Label")).to be_nil
    end
  end

  describe "#fill! via the :TU options-map (compile-then-fill path)" do
    # Build a PDF whose ChoiceField has a pre-populated :TU JSON
    # options_map — the exact shape that compile! writes. fill! must read
    # it to translate a lowercase payload value into the AcroForm export.
    def pdf_with_tu_choice(path)
      doc = HexaPDF::Document.new
      page = doc.pages.add
      form = doc.acro_form(create: true)
      ch = form.create_combo_box("marital_status",
        option_items: ["Single", "Married", "Divorced", "Widowed"],
        font: "Helvetica")
      ch.create_widget(page, Rect: [100, 100, 300, 120])
      ch[:TU] = {"single" => "Single", "married" => "Married",
                 "divorced" => "Divorced", "widowed" => "Widowed"}.to_json
      doc.write(path)
      path
    end

    it "resolves a lowercase payload value into the AcroForm export via :TU" do
      pdf = pdf_with_tu_choice(File.join(@tmp, "tu.pdf"))
      out = File.join(@tmp, "filled.pdf")

      silence_stdout do
        described_class.new(pdf, normalized_dir: @tmp).fill!({marital_status: "married"}, out)
      end

      filled = HexaPDF::Document.open(out)
      field = filled.acro_form.each_field.find { |f| f.full_field_name == "marital_status" }
      expect(field.field_value).to eq("Married")
    end
  end

  describe "#preserved_options_map" do
    it "returns a string→string identity map for a choice field's option_items" do
      engine = described_class.new(semantic_fixture, normalized_dir: @tmp)
      form = HexaPDF::Document.open(semantic_fixture).acro_form
      choice = form.each_field.find { |f| f.field_type == :Ch }

      result = engine.send(:preserved_options_map, choice)
      expect(result).to be_a(Hash)
      expect(result).not_to be_empty
      result.each { |k, v| expect(k).to eq(v) }
    end

    it "returns {} (never nil) for fields with no options" do
      engine = described_class.new(semantic_fixture, normalized_dir: @tmp)
      form = HexaPDF::Document.open(semantic_fixture).acro_form
      text = form.each_field.find { |f| f.field_type == :Tx }
      expect(engine.send(:preserved_options_map, text)).to eq({})
    end
  end

  describe "#fill! image-upload auto-stamping" do
    def pdf_with_image_field(path)
      doc = HexaPDF::Document.new
      page = doc.pages.add
      form = doc.acro_form(create: true)
      field = form.create_check_box("passport_photo")
      field.flag(:push_button)
      field.create_widget(page, Rect: [100, 600, 200, 720])
      doc.write(path)
      path
    end

    def png_1x1
      bytes = "\x89PNG\r\n\x1a\n" \
        "\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01" \
        "\x08\x06\x00\x00\x00\x1f\x15\xc4\x89" \
        "\x00\x00\x00\rIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01" \
        "\r\n-\xb4" \
        "\x00\x00\x00\x00IEND\xaeB`\x82"
      bytes.b
    end

    def write_png(dir, name, bytes = png_1x1)
      path = File.join(dir, name)
      File.binwrite(path, bytes)
      path
    end

    it "stamps the payload's image when the field is a push-button and the value is a file path" do
      pdf = pdf_with_image_field(File.join(@tmp, "image.pdf"))
      img = write_png(@tmp, "tiny.png")
      out = File.join(@tmp, "filled.pdf")

      result = silence_stdout do
        described_class.new(pdf, normalized_dir: @tmp).fill!({passport_photo: img}, out)
      end

      expect(result[:filled]).to have_key(:passport_photo)
      doc = HexaPDF::Document.open(out)
      xobjects = doc.pages.first.resources[:XObject] || {}
      images = xobjects.value.values.map { |ref| doc.deref(ref) }
        .select { |o| o.respond_to?(:[]) && o[:Subtype] == :Image }
      expect(images).not_to be_empty
    end

    it "raises ImageTooLargeError when the file exceeds MAX_IMAGE_BYTES" do
      pdf = pdf_with_image_field(File.join(@tmp, "image.pdf"))
      huge = File.join(@tmp, "huge.png")
      File.binwrite(huge, "\x89PNG\r\n\x1a\n" + ("x" * (AcroForge::ImageStamper::MAX_IMAGE_BYTES + 1)))
      out = File.join(@tmp, "filled.pdf")

      expect {
        silence_stdout do
          described_class.new(pdf, normalized_dir: @tmp).fill!({passport_photo: huge}, out)
        end
      }.to raise_error(AcroForge::ImageTooLargeError, /exceeds.*byte/)
    end

    it "raises UnsupportedImageFormatError for non-JPG/PNG files" do
      pdf = pdf_with_image_field(File.join(@tmp, "image.pdf"))
      txt = File.join(@tmp, "doc.txt")
      File.write(txt, "hello")
      out = File.join(@tmp, "filled.pdf")

      expect {
        silence_stdout do
          described_class.new(pdf, normalized_dir: @tmp).fill!({passport_photo: txt}, out)
        end
      }.to raise_error(AcroForge::UnsupportedImageFormatError)
    end

    it "infers :passport_photo / :signature from widget geometry during compile!" do
      doc = HexaPDF::Document.new
      page = doc.pages.add
      form = doc.acro_form(create: true)
      # Square-ish: passport. 63x73, AR ≈ 0.86.
      passport = form.create_check_box("Image37_af_image")
      passport.flag(:push_button)
      passport.create_widget(page, Rect: [515, 652, 579, 725])
      # Wide-thin: signature. 145x23, AR ≈ 6.3.
      signature = form.create_check_box("Image112_af_image")
      signature.flag(:push_button)
      signature.create_widget(page, Rect: [439, 663, 584, 686])
      src = File.join(@tmp, "geom.pdf")
      doc.write(src)

      engine = described_class.new(src, normalized_dir: @tmp)
      silence_stdout { engine.compile! }

      mapped = engine.field_proposals.each_with_object({}) { |p, h|
        h[p[:pdf_field_name]] = p[:canonical_key]
      }
      expect(mapped["Image37_af_image"]).to eq(:passport_photo)
      expect(mapped["Image112_af_image"]).to eq(:signature)
    end
  end
end
