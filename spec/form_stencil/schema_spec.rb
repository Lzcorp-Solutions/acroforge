# frozen_string_literal: true

require "spec_helper"
require "form_stencil/schema"

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
end
