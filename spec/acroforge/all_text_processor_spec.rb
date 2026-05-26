# frozen_string_literal: true

require "spec_helper"
require "hexapdf"
require "acroforge/all_text_processor"

RSpec.describe AcroForge::AllTextProcessor do
  let(:fixture_path) { File.expand_path("../fixtures/semantic_named.pdf", __dir__) }

  it "extracts text chunks from a PDF page" do
    doc = HexaPDF::Document.open(fixture_path)
    processor = described_class.new
    doc.pages.first.process_contents(processor)

    chunks = processor.text_chunks
    expect(chunks).to be_an(Array)
    expect(chunks).not_to be_empty
    expect(chunks.first).to include(:text, :x_min, :y_min, :x_max, :y_max)
  end

  describe "post-merge normalization" do
    # PDFs sometimes render each glyph as a separate text object. After
    # merge_fragments joins them with spaces, the merged text looks like
    # "M o d e O f R e p a y m e n t". text_chunks must re-normalize so
    # those spaced-letter sequences collapse back into real words.
    it "collapses spaced-letter sequences that appear only after merging" do
      processor = described_class.new
      # Inject raw chunks directly to simulate per-glyph extraction with
      # tight horizontal positioning that merge_fragments will join.
      x = 100
      "ModeOfRepayment".each_char do |ch|
        processor.instance_variable_get(:@raw_chunks) << {
          text: ch, x_min: x, y_min: 100, x_max: x + 6, y_max: 110
        }
        x += 8
      end

      text = processor.text_chunks.map { |c| c[:text] }.first
      expect(text).not_to include("M o d e")
      expect(text).to eq("Mode Of Repayment")
    end

    it "recovers word breaks from CamelCase after collapse" do
      processor = described_class.new
      x = 100
      "LoanTenorApproved".each_char do |ch|
        processor.instance_variable_get(:@raw_chunks) << {
          text: ch, x_min: x, y_min: 100, x_max: x + 6, y_max: 110
        }
        x += 8
      end

      expect(processor.text_chunks.map { |c| c[:text] }.first).to eq("Loan Tenor Approved")
    end

    it "tightens spaces around parentheses introduced by glyph extraction" do
      processor = described_class.new
      x = 100
      "( ForDisbursement )".each_char do |ch|
        processor.instance_variable_get(:@raw_chunks) << {
          text: ch, x_min: x, y_min: 100, x_max: x + 6, y_max: 110
        }
        x += 8
      end

      expect(processor.text_chunks.map { |c| c[:text] }.first).to eq("(For Disbursement)")
    end

    it "collapses 'D a t e' to 'Date'" do
      processor = described_class.new
      x = 100
      "Date".each_char do |ch|
        processor.instance_variable_get(:@raw_chunks) << {
          text: ch, x_min: x, y_min: 100, x_max: x + 6, y_max: 110
        }
        x += 8
      end

      expect(processor.text_chunks.map { |c| c[:text] }.first).to eq("Date")
    end
  end
end
