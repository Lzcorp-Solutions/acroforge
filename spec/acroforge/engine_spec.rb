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

  describe "#compile! _btn suffix is idempotent" do
    it "does not double-suffix a button field whose canonical key already ends in _btn" do
      # Override gives a button field a key that already ends in _btn; the engine
      # must not produce :something_btn_btn.
      overrides = {
        "page0_field10" => {key: :gender_btn, type: :select}
      }
      engine = described_class.new(garbage_fixture, overrides: overrides, normalized_dir: @tmp)
      result = silence_stdout { engine.compile! }

      values = result[:mapped].values.map(&:to_s)
      expect(values).to include("gender_btn")
      expect(values.grep(/_btn_btn/)).to be_empty
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
end
