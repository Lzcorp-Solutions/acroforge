# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "acroforge"

RSpec.describe AcroForge::ImageStamper do
  around do |example|
    Dir.mktmpdir do |tmp|
      @tmp = tmp
      example.run
    end
  end

  describe "#validate_image!" do
    it "raises UnsupportedImageFormatError on an empty file" do
      empty = File.join(@tmp, "empty.png")
      File.binwrite(empty, "")

      expect {
        described_class.new.validate_image!(empty)
      }.to raise_error(AcroForge::UnsupportedImageFormatError)
    end

    it "raises UnsupportedImageFormatError on a truncated PNG header" do
      truncated = File.join(@tmp, "truncated.png")
      File.binwrite(truncated, "\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR")

      expect {
        described_class.new.validate_image!(truncated)
      }.to raise_error(AcroForge::UnsupportedImageFormatError, /truncated/)
    end

    it "raises UnsupportedImageFormatError on a truncated JPEG (no SOF)" do
      truncated = File.join(@tmp, "truncated.jpg")
      File.binwrite(truncated, "\xFF\xD8\xFF\xE0\x00\x10JFIF\x00")

      expect {
        described_class.new.validate_image!(truncated)
      }.to raise_error(AcroForge::UnsupportedImageFormatError)
    end

    it "raises ImageTooLargeError when pixel dimensions exceed MAX_IMAGE_DIMENSION" do
      huge_png = File.join(@tmp, "huge.png")
      header = "\x89PNG\r\n\x1A\n".b
      ihdr_chunk_header = "\x00\x00\x00\rIHDR".b
      ihdr_data = [10_000, 10_000, 8, 6, 0, 0, 0].pack("NNCCCCC")
      File.binwrite(huge_png, header + ihdr_chunk_header + ihdr_data)

      expect {
        described_class.new.validate_image!(huge_png)
      }.to raise_error(AcroForge::ImageTooLargeError, /per side/)
    end
  end
end
