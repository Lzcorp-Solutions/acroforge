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
end
