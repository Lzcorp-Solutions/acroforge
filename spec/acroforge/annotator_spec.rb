# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "yaml"
require "hexapdf"
require "acroforge"

RSpec.describe AcroForge::Annotator do
  let(:garbage_fixture) { File.expand_path("../fixtures/garbage_named.pdf", __dir__) }

  around do |example|
    Dir.mktmpdir do |tmp|
      @tmp = tmp
      example.run
    end
  end

  describe ".annotate" do
    it "writes an annotated PDF with one badge per AcroForm field (bare mode)" do
      out = File.join(@tmp, "annotated.pdf")
      result = described_class.annotate(garbage_fixture, out: out)

      expect(result[:annotated]).to be > 0
      expect(result[:mapped]).to eq(0)
      expect(result[:unmapped]).to eq(0)
      expect(File.exist?(out)).to be true

      # The annotated PDF still has its AcroForm intact
      doc = HexaPDF::Document.open(out)
      expect(doc.acro_form.each_field.to_a).not_to be_empty
    end

    it "categorizes fields by mapping state (mapped / unmapped / missing)" do
      out = File.join(@tmp, "annotated.pdf")
      mapping = File.join(@tmp, "mapping.yml")

      # Mapping that only mentions 2 of the 16 fields, demonstrating all
      # three categories: mapped (key set), unmapped (key nil), missing
      # (not in the mapping file at all).
      File.write(mapping, YAML.dump({
        "_meta" => {"source_pdf" => garbage_fixture},
        "page0_field6" => {"key" => "full_name", "type" => "string"},
        "page0_field28" => {"key" => nil, "type" => nil}
      }))

      result = described_class.annotate(garbage_fixture, out: out, mapping: mapping)
      expect(result[:mapped]).to eq(1)
      expect(result[:unmapped]).to eq(1)
      expect(result[:missing]).to eq(result[:annotated] - 2)
    end

    it "raises RelabelError on a PDF without an AcroForm" do
      no_form = File.expand_path("../fixtures/no_acroform.pdf", __dir__)
      out = File.join(@tmp, "annotated.pdf")
      expect {
        described_class.annotate(no_form, out: out)
      }.to raise_error(AcroForge::RelabelError, /no AcroForm/)
    end
  end
end
