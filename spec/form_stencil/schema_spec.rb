# frozen_string_literal: true

require "spec_helper"
require "form_stencil/schema"
require "tmpdir"
require "yaml"

RSpec.describe FormStencil::Schema do
  describe ".normalize" do
    it "upgrades legacy {key => [variations]} to rich form" do
      legacy = {full_name: ["First Name", "Surname"], dob: ["Date of Birth"]}
      result = described_class.normalize(legacy)
      expect(result).to eq(
        full_name: {type: :string, variations: ["First Name", "Surname"]},
        dob: {type: :string, variations: ["Date of Birth"]}
      )
    end

    it "passes rich form through unchanged" do
      rich = {
        gender: {type: :select, variations: ["Gender"], options: [:male, :female]}
      }
      expect(described_class.normalize(rich)).to eq(rich)
    end

    it "handles a mixed input (some legacy, some rich)" do
      mixed = {
        full_name: ["First Name"],
        gender: {type: :select, variations: ["Gender"], options: [:male]}
      }
      result = described_class.normalize(mixed)
      expect(result[:full_name][:type]).to eq(:string)
      expect(result[:full_name][:variations]).to eq(["First Name"])
      expect(result[:gender]).to eq(type: :select, variations: ["Gender"], options: [:male])
    end

    it "returns an empty hash for an empty input" do
      expect(described_class.normalize({})).to eq({})
    end
  end

  describe ".load and .dump" do
    around do |example|
      Dir.mktmpdir do |tmp|
        @tmp = tmp
        example.run
      end
    end

    let(:schema) do
      {
        full_name: {type: :string, variations: ["First Name", "Surname"]},
        gender: {type: :select, variations: ["Gender"], options: [:male, :female]}
      }
    end

    it "round-trips through YAML" do
      path = File.join(@tmp, "schema.yml")
      described_class.dump(schema, path)
      reloaded = described_class.load(path)
      expect(reloaded).to eq(schema)
    end

    it "round-trips through JSON" do
      path = File.join(@tmp, "schema.json")
      described_class.dump(schema, path)
      reloaded = described_class.load(path)
      expect(reloaded).to eq(schema)
    end

    it "raises on unknown extension" do
      path = File.join(@tmp, "schema.txt")
      expect { described_class.dump(schema, path) }.to raise_error(ArgumentError, /extension/)
    end

    it "load returns a normalized rich-form hash even if the file is legacy form" do
      path = File.join(@tmp, "legacy.yml")
      File.write(path, YAML.dump(full_name: ["First Name"]))
      result = described_class.load(path)
      expect(result[:full_name]).to eq(type: :string, variations: ["First Name"])
    end
  end

  describe ".infer" do
    let(:semantic_fixture) { File.expand_path("../fixtures/semantic_named.pdf", __dir__) }

    it "produces a non-empty rich-form schema from a PDF" do
      result = silence_stdout { described_class.infer(semantic_fixture) }
      expect(result).to be_a(Hash)
      expect(result).not_to be_empty
      first_entry = result.values.first
      expect(first_entry).to include(:type, :variations)
      expect(first_entry[:variations]).to be_an(Array)
    end

    it "aggregates duplicate raw labels into one entry per canonical key" do
      result = silence_stdout { described_class.infer(semantic_fixture) }
      result.each_value do |entry|
        expect(entry[:variations]).to eq(entry[:variations].uniq)
      end
    end
  end
end
