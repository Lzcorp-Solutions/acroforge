# frozen_string_literal: true

require "spec_helper"
require "acroforge/schema"
require "tmpdir"
require "yaml"

RSpec.describe AcroForge::Schema do
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

    it "emits YAML in human-readable form (no leading-colon symbol prefix)" do
      path = File.join(@tmp, "human.yml")
      described_class.dump(schema, path)
      contents = File.read(path)
      expect(contents).not_to match(/: ":\w+"/)
      expect(contents).to match(/type: string/)
      expect(contents).to match(/^- male/m).or match(/- male/)
    end

    it "loads a hand-written YAML where type and options are plain strings" do
      path = File.join(@tmp, "hand_written.yml")
      File.write(path, <<~YAML)
        full_name:
          type: string
          variations:
            - First Name
        gender:
          type: select
          variations:
            - Gender
          options:
            - male
            - female
      YAML
      result = described_class.load(path)
      expect(result[:full_name][:type]).to eq(:string)
      expect(result[:gender][:type]).to eq(:select)
      expect(result[:gender][:options]).to eq([:male, :female])
    end
  end

  describe ".infer" do
    let(:semantic_fixture) { File.expand_path("../fixtures/semantic_named.pdf", __dir__) }

    it "produces a non-empty rich-form schema from a PDF" do
      result = silence_stdout { described_class.infer(semantic_fixture) }
      expect(result).to be_a(Hash)
      expect(result).not_to be_empty
      first_entry = result.values.first
      expect(first_entry).to include(:type)
      # :variations is optional — preserved fields and entries with no
      # meaningful spatial label omit it. When present, it's an Array.
      expect(first_entry[:variations]).to be_an(Array) if first_entry.key?(:variations)
    end

    it "aggregates duplicate raw labels into one entry per canonical key" do
      result = silence_stdout { described_class.infer(semantic_fixture) }
      result.each_value do |entry|
        next unless entry.key?(:variations)
        expect(entry[:variations]).to eq(entry[:variations].uniq)
      end
    end
  end

  describe ".merge" do
    it "adds new canonical keys for mapping entries the schema doesn't know" do
      schema = {full_name: {type: :string, variations: ["Full Name"]}}
      mapping = {
        "page0_field6" => {"key" => "phone_number", "type" => "string", "meta" => {"raw_label" => "Phone Number"}}
      }
      result = described_class.merge(schema, mapping)
      expect(result.keys).to contain_exactly(:full_name, :phone_number)
      expect(result[:phone_number]).to eq(type: :string, variations: ["Phone Number"])
    end

    it "adds new variations to existing canonical keys without duplicating" do
      schema = {full_name: {type: :string, variations: ["Full Name"]}}
      mapping = {
        "page0_field6" => {"key" => "full_name", "type" => "string", "meta" => {"raw_label" => "Customer Name"}},
        "page0_field28" => {"key" => "full_name", "type" => "string", "meta" => {"raw_label" => "Full Name"}}
      }
      result = described_class.merge(schema, mapping)
      expect(result[:full_name][:variations]).to eq(["Full Name", "Customer Name"])
    end

    it "strips the _N collision suffix when deriving the canonical key" do
      schema = {}
      mapping = {
        "page0_field6" => {"key" => "full_name", "type" => "string", "meta" => {"raw_label" => "Name A"}},
        "page0_field28" => {"key" => "full_name_1", "type" => "string", "meta" => {"raw_label" => "Name B"}}
      }
      result = described_class.merge(schema, mapping)
      expect(result.keys).to eq([:full_name])
      expect(result[:full_name][:variations]).to contain_exactly("Name A", "Name B")
    end

    it "skips entries with null or empty key, and _meta sentinels" do
      schema = {existing: {type: :string, variations: ["E"]}}
      mapping = {
        "_meta" => {"source_pdf" => "f.pdf"},
        "page0_field6" => {"key" => nil, "type" => "string", "meta" => {"raw_label" => "Skip Me"}},
        "page0_field7" => {"key" => "", "type" => "string"},
        "page0_field8" => {"key" => "kept", "type" => "string", "meta" => {"raw_label" => "Kept"}}
      }
      result = described_class.merge(schema, mapping)
      expect(result.keys).to contain_exactly(:existing, :kept)
    end

    it "does not mutate the input schema" do
      schema = {full_name: {type: :string, variations: ["Full Name"]}}
      original = schema.dup
      original_variations = schema[:full_name][:variations].dup
      mapping = {
        "page0_field6" => {"key" => "full_name", "type" => "string", "meta" => {"raw_label" => "New Variation"}}
      }
      described_class.merge(schema, mapping)
      expect(schema).to eq(original)
      expect(schema[:full_name][:variations]).to eq(original_variations)
    end
  end

  describe ".humanize_label" do
    it "fixes typos derived from TYPO_PHRASE_REPLACEMENTS" do
      expect(described_class.humanize_label("Tax Identi fi cation No.")).to eq("Tax Identification No.")
      expect(described_class.humanize_label("Date of Con rmed Employment")).to eq("Date of Confirmed Employment")
      expect(described_class.humanize_label("Na onal Insurance")).to eq("National Insurance")
      expect(described_class.humanize_label("ModeOf Repayment")).to eq("Mode of Repayment")
    end

    it "preserves clean labels unchanged" do
      expect(described_class.humanize_label("Full Name")).to eq("Full Name")
      expect(described_class.humanize_label("Email Address")).to eq("Email Address")
    end

    it "returns the input unchanged for nil / empty / non-string" do
      expect(described_class.humanize_label(nil)).to be_nil
      expect(described_class.humanize_label("")).to eq("")
      expect(described_class.humanize_label(:symbol)).to eq(:symbol)
    end

    it "collapses incidental whitespace" do
      expect(described_class.humanize_label("Full   Name   ")).to eq("Full Name")
    end

    it "strips parenthetical UI hints" do
      expect(described_class.humanize_label("Date of Birth (YYYY-MM-DD)")).to eq("Date of Birth")
      expect(described_class.humanize_label("Amount (GHS)")).to eq("Amount")
    end

    it "renders snake_case input as space-separated title case" do
      expect(described_class.humanize_label("other_bank")).to eq("Other Bank")
      expect(described_class.humanize_label("first_name")).to eq("First Name")
      expect(described_class.humanize_label("application_no")).to eq("Application No")
    end
  end

  describe "empty :variations cleanup" do
    it ".aggregate_proposals omits :variations when no labels were captured" do
      proposals = [
        {canonical_key: :first_name, raw_label: "first_name", confidence: :preserved,
         pdf_field_type: :text, options: nil},
        {canonical_key: :email, raw_label: "email", confidence: :preserved,
         pdf_field_type: :text, options: nil}
      ]
      result = described_class.aggregate_proposals(proposals)
      expect(result[:first_name]).to eq(type: :string)
      expect(result[:email]).to eq(type: :email)
      result.each_value { |v| expect(v).not_to have_key(:variations) }
    end

    it ".merge drops empty variations on copied entries that had none" do
      schema = {full_name: {type: :string}}
      mapping = {"some_field" => {"key" => "phone", "type" => "string", "meta" => {}}}
      result = described_class.merge(schema, mapping)
      # The pre-existing full_name had no variations; it must NOT gain a hollow [].
      expect(result[:full_name]).to eq(type: :string)
      # phone got no raw_label either, so it's clean too.
      expect(result[:phone]).to eq(type: :string)
    end
  end

  describe ".infer_type snake_case handling" do
    let(:p) { ->(label) { {pdf_field_type: :text, raw_label: label, options: nil} } }

    it "infers :date for snake_case names containing date/dob/expiry/employed/birth" do
      expect(described_class.send(:infer_type, p["date_signed"])).to eq(:date)
      expect(described_class.send(:infer_type, p["dob"])).to eq(:date)
      expect(described_class.send(:infer_type, p["id_expiry"])).to eq(:date)
      expect(described_class.send(:infer_type, p["date_employed"])).to eq(:date)
    end

    it "infers :number when snake_case names end in _no" do
      expect(described_class.send(:infer_type, p["account_no"])).to eq(:number)
      expect(described_class.send(:infer_type, p["loan_tenor"])).to eq(:number)
    end

    it "still classifies plain strings as :string" do
      expect(described_class.send(:infer_type, p["customer_signature"])).to eq(:string)
      expect(described_class.send(:infer_type, p["postal_address"])).to eq(:string)
    end
  end
end
