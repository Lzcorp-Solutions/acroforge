# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "form_stencil"

RSpec.describe FormStencil::Engine do
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
      }.to raise_error(FormStencil::ValidationError)
    end
  end
end
