# frozen_string_literal: true

require "spec_helper"

RSpec.describe AcroForge::Labels do
  describe ".strip_parenthetical" do
    it "removes parenthetical UI hints" do
      expect(described_class.strip_parenthetical("Date of Birth (YYYY-MM-DD)")).to eq("Date of Birth")
      expect(described_class.strip_parenthetical("Amount (GHS)")).to eq("Amount")
    end

    it "removes only the parens content, leaving the rest intact" do
      expect(described_class.strip_parenthetical("Foo (a) Bar (b) Baz")).to eq("Foo Bar Baz")
    end

    it "is a no-op for strings with no parentheses" do
      expect(described_class.strip_parenthetical("Full Name")).to eq("Full Name")
    end

    it "coerces non-string input via to_s" do
      expect(described_class.strip_parenthetical(nil)).to eq("")
      expect(described_class.strip_parenthetical(:full_name)).to eq("full_name")
    end

    it "collapses incidental whitespace introduced by the strip" do
      expect(described_class.strip_parenthetical("  Foo  (x)   ")).to eq("Foo")
    end
  end
end
