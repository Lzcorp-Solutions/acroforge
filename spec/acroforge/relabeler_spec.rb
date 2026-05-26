# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "yaml"
require "fileutils"
require "stringio"
require "acroforge"

RSpec.describe AcroForge::Relabeler do
  let(:garbage_fixture) { File.expand_path("../fixtures/garbage_named.pdf", __dir__) }

  around do |example|
    Dir.mktmpdir do |tmp|
      @tmp = tmp
      example.run
    end
  end

  describe ".propose" do
    it "writes a mapping YAML file with the documented structure" do
      out_path = File.join(@tmp, "mapping.yml")
      silence_stdout { described_class.propose(garbage_fixture, out: out_path) }

      data = YAML.load_file(out_path)
      expect(data).to include("_meta")
      expect(data["_meta"]).to include("source_pdf", "generated_at", "acroforge_version", "total_fields")

      entries = data.reject { |k, _| k.to_s.start_with?("_") }
      expect(entries).not_to be_empty

      first = entries.values.first
      expect(first).to include("key", "type", "meta")
      expect(first["meta"]).to include("raw_label", "confidence", "section", "page")

      # Entry keys must be the ORIGINAL PDF field names (page0_fieldX),
      # not the semantic names assigned by the heuristic.
      pdf_field_names_in_mapping = entries.keys
      expect(pdf_field_names_in_mapping).to all(match(/^page\d+_field\d+$/))
      expect(pdf_field_names_in_mapping).to include("page0_field6", "page0_field28")
    end

    it "sorts entries by page, then y (top-to-bottom), then x (left-to-right)" do
      out_path = File.join(@tmp, "mapping.yml")
      silence_stdout { described_class.propose(garbage_fixture, out: out_path) }

      data = YAML.load_file(out_path)
      entries = data.reject { |k, _| k.to_s.start_with?("_") }
      pages_seen = entries.values.map { |e| e["meta"]["page"] }
      expect(pages_seen).to eq(pages_seen.sort)
    end

    it "preserves user-edited key/type values in :merge mode" do
      out_path = File.join(@tmp, "mapping.yml")
      silence_stdout { described_class.propose(garbage_fixture, out: out_path) }

      data = YAML.load_file(out_path)
      first_pdf_key = data.reject { |k, _| k.to_s.start_with?("_") }.keys.first
      data[first_pdf_key]["key"] = "manually_edited_name"
      data[first_pdf_key]["type"] = "string"
      File.write(out_path, YAML.dump(data))

      silence_stdout { described_class.propose(garbage_fixture, out: out_path, mode: :merge) }

      reloaded = YAML.load_file(out_path)
      expect(reloaded[first_pdf_key]["key"]).to eq("manually_edited_name")
    end

    it "ignores existing edits in :overwrite mode" do
      out_path = File.join(@tmp, "mapping.yml")
      silence_stdout { described_class.propose(garbage_fixture, out: out_path) }

      data = YAML.load_file(out_path)
      first_pdf_key = data.reject { |k, _| k.to_s.start_with?("_") }.keys.first
      data[first_pdf_key]["key"] = "manually_edited_name"
      File.write(out_path, YAML.dump(data))

      silence_stdout { described_class.propose(garbage_fixture, out: out_path, mode: :overwrite) }

      reloaded = YAML.load_file(out_path)
      expect(reloaded[first_pdf_key]["key"]).not_to eq("manually_edited_name")
    end
  end

  describe ".apply!" do
    it "renames AcroForm fields to the keys specified in the mapping" do
      pdf_copy = File.join(@tmp, "pdf.pdf")
      FileUtils.cp(garbage_fixture, pdf_copy)
      mapping = File.join(@tmp, "mapping.yml")

      File.write(mapping, YAML.dump({
        "_meta" => {"source_pdf" => pdf_copy},
        "page0_field6" => {"key" => "full_name", "type" => "string"}
      }))

      silence_stdout { described_class.apply!(pdf_copy, mapping) }

      require "hexapdf"
      doc = HexaPDF::Document.open(pdf_copy)
      names = doc.acro_form.each_field.map(&:full_field_name)
      expect(names).to include("full_name")
      expect(names).not_to include("page0_field6")
    end

    it "auto-disambiguates collisions with _1, _2 suffixes" do
      pdf_copy = File.join(@tmp, "pdf.pdf")
      FileUtils.cp(garbage_fixture, pdf_copy)
      mapping = File.join(@tmp, "mapping.yml")

      File.write(mapping, YAML.dump({
        "page0_field6" => {"key" => "full_name", "type" => "string"},
        "page0_field28" => {"key" => "full_name", "type" => "string"}
      }))

      silence_stdout { described_class.apply!(pdf_copy, mapping) }

      require "hexapdf"
      doc = HexaPDF::Document.open(pdf_copy)
      names = doc.acro_form.each_field.map(&:full_field_name)
      expect(names).to include("full_name")
      expect(names).to include("full_name_1")
    end

    it "skips entries with null key" do
      pdf_copy = File.join(@tmp, "pdf.pdf")
      FileUtils.cp(garbage_fixture, pdf_copy)
      mapping = File.join(@tmp, "mapping.yml")

      File.write(mapping, YAML.dump({
        "page0_field6" => {"key" => nil, "type" => nil}
      }))

      silence_stdout { described_class.apply!(pdf_copy, mapping) }

      require "hexapdf"
      doc = HexaPDF::Document.open(pdf_copy)
      names = doc.acro_form.each_field.map(&:full_field_name)
      expect(names).to include("page0_field6")
    end

    it "raises RelabelError when a key fails the regex" do
      pdf_copy = File.join(@tmp, "pdf.pdf")
      FileUtils.cp(garbage_fixture, pdf_copy)
      mapping = File.join(@tmp, "mapping.yml")

      File.write(mapping, YAML.dump({
        "page0_field6" => {"key" => "1_invalid_start", "type" => "string"}
      }))

      expect {
        silence_stdout { described_class.apply!(pdf_copy, mapping) }
      }.to raise_error(AcroForge::RelabelError, /key/)
    end

    it "warns on stale entries but does not raise" do
      pdf_copy = File.join(@tmp, "pdf.pdf")
      FileUtils.cp(garbage_fixture, pdf_copy)
      mapping = File.join(@tmp, "mapping.yml")

      File.write(mapping, YAML.dump({
        "nonexistent_field_name" => {"key" => "foo", "type" => "string"}
      }))

      stderr_io = StringIO.new
      orig = $stderr
      $stderr = stderr_io
      begin
        silence_stdout { described_class.apply!(pdf_copy, mapping) }
      ensure
        $stderr = orig
      end
      expect(stderr_io.string).to match(/stale|not found|missing/i)
    end
  end
end
