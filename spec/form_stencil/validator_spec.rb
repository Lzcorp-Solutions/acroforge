# frozen_string_literal: true

require "spec_helper"
require "form_stencil/validator"

RSpec.describe FormStencil::Validator do
  describe ".valid?" do
    it "passes nil and empty string for any type" do
      expect(described_class.valid?(nil, :money)).to be true
      expect(described_class.valid?("", :date)).to be true
    end

    it "validates money" do
      expect(described_class.valid?("1,234.56", :money)).to be true
      expect(described_class.valid?("$99", :money)).to be true
      expect(described_class.valid?("abc", :money)).to be false
    end

    it "validates date" do
      expect(described_class.valid?("2026-05-26", :date)).to be true
      expect(described_class.valid?("not a date", :date)).to be false
    end

    it "validates email" do
      expect(described_class.valid?("a@b.co", :email)).to be true
      expect(described_class.valid?("not-an-email", :email)).to be false
    end

    it "validates number" do
      expect(described_class.valid?("12345", :number)).to be true
      expect(described_class.valid?("12 34", :number)).to be true
      expect(described_class.valid?("12.5", :number)).to be false
    end

    it "validates boolean" do
      %w[true false yes no 1 0 on off].each do |v|
        expect(described_class.valid?(v, :boolean)).to be true
      end
      expect(described_class.valid?("maybe", :boolean)).to be false
    end

    it "validates select against options (case-insensitive)" do
      expect(described_class.valid?("Male", :select, [:male, :female])).to be true
      expect(described_class.valid?("other", :select, [:male, :female])).to be false
    end

    it "treats unknown types as always valid (string default)" do
      expect(described_class.valid?("anything", :string)).to be true
      expect(described_class.valid?("anything", :something_else)).to be true
    end
  end
end
