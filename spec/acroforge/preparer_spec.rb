# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "hexapdf"
require "acroforge"

RSpec.describe AcroForge::Preparer do
  let(:semantic_fixture) { File.expand_path("../fixtures/semantic_named.pdf", __dir__) }

  around do |example|
    Dir.mktmpdir do |tmp|
      @tmp = tmp
      example.run
    end
  end

  def fixture_with_duplicate_dates
    doc = HexaPDF::Document.new
    page = doc.pages.add
    canvas = page.canvas
    canvas.font("Helvetica", size: 10)

    # Three fields all literally named "date", each near a distinct visible label
    [["Signature Date", 700], ["Confirmed Date", 650], ["Other Date", 600]].each do |label, y|
      canvas.text(label, at: [72, y + 4])
      field = doc.acro_form(create: true).create_text_field("date")
      field.create_widget(page, Rect: [180, y, 380, y + 14])
    end

    path = File.join(@tmp, "dupes.pdf")
    doc.write(path, validate: false)
    path
  end

  it "is a no-op for PDFs with no duplicate field names" do
    out = File.join(@tmp, "out.pdf")
    result = silence_stdout { described_class.prepare!(semantic_fixture, out: out) }
    expect(result[:duplicate_groups]).to eq(0)
    expect(result[:renamed]).to eq(0)
  end

  it "renames each duplicate field to its heuristic-proposed unique key" do
    pdf = fixture_with_duplicate_dates
    result = silence_stdout { described_class.prepare!(pdf) }

    expect(result[:duplicate_groups]).to eq(1)
    expect(result[:renamed]).to eq(3)

    # After prepare, no two fields share a name
    doc = HexaPDF::Document.open(pdf)
    names = doc.acro_form.each_field.map(&:full_field_name)
    expect(names.uniq.length).to eq(names.length)
    expect(names).not_to include("date")  # all three should have been renamed
  end

  it "writes to an explicit --out path when given, leaving the source untouched" do
    pdf = fixture_with_duplicate_dates
    out = File.join(@tmp, "prepared.pdf")
    original_names = HexaPDF::Document.open(pdf).acro_form.each_field.map(&:full_field_name)

    silence_stdout { described_class.prepare!(pdf, out: out) }

    expect(File.exist?(out)).to be true
    expect(HexaPDF::Document.open(pdf).acro_form.each_field.map(&:full_field_name)).to eq(original_names)
    new_names = HexaPDF::Document.open(out).acro_form.each_field.map(&:full_field_name)
    expect(new_names.uniq.length).to eq(new_names.length)
  end
end
