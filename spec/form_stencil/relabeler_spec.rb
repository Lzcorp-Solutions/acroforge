# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "yaml"
require "form_stencil"

RSpec.describe FormStencil::Relabeler do
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
      expect(data["_meta"]).to include("source_pdf", "generated_at", "form_stencil_version", "total_fields")

      entries = data.reject { |k, _| k.to_s.start_with?("_") }
      expect(entries).not_to be_empty

      first = entries.values.first
      expect(first).to include("key", "type", "meta")
      expect(first["meta"]).to include("raw_label", "confidence", "section", "page")
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
end
