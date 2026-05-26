# frozen_string_literal: true

require "hexapdf"

module FormStencil
  class AllTextProcessor < HexaPDF::Content::Processor
    def initialize
      super
      @raw_chunks = []
    end

    def show_text(str)
      process_text(str)
    end

    def show_text_with_positioning(arr)
      process_text(arr)
    end

    def text_chunks
      merge_fragments(@raw_chunks)
    end

    private

    def process_text(data)
      text_pos = decode_text_with_positioning(data)

      str = normalize_extracted_text(text_pos.string)
      return if str.empty?

      @raw_chunks << {
        text: str,
        x_min: text_pos.lower_left[0],
        y_min: text_pos.lower_left[1],
        x_max: text_pos.upper_right[0],
        y_max: text_pos.upper_right[1]
      }
    rescue HexaPDF::Error
      nil
    end

    def normalize_extracted_text(raw_text)
      str = raw_text.to_s.tr(" ", " ")
      str = str.gsub(/\s+/, " ").strip

      # Fix split apostrophes like "Customer ' s".
      str = str.gsub(/\s+['’]\s+/, "'")

      # Collapse only clear spaced-letter sequences like "C u s t o m e r".
      str = str.gsub(/\b(?:\p{L}\s+){2,}\p{L}\b/) { |m| m.gsub(/\s+/, "") }

      # Merge split fragments that commonly appear in broken PDF extraction,
      # e.g. "c ertify", "h as", "th at", "o ther".
      loop do
        previous = str

        # One-letter consonant + token: "c ertify" => "certify", "h as" => "has".
        str = str.gsub(/\b([bcdfghjklmnpqrstvwxyz])\s+([a-z]{2,})\b/i, '\\1\\2')

        # Common 2-letter heads: "th at" => "that", "ot her" => "other".
        str = str.gsub(/\b(th|wh|ot|pr|tr|cl|gr|fr|br|dr|st|sp|ch)\s+([a-z]{2,})\b/i, '\\1\\2')

        break if str == previous
      end

      str.gsub(/\s+/, " ").strip
    end

    def merge_fragments(chunks)
      sorted = chunks.sort_by { |c| [-c[:y_min], c[:x_min]] }
      merged = []

      sorted.each do |chunk|
        if merged.empty?
          merged << chunk
        else
          last = merged.last

          if (last[:y_min] - chunk[:y_min]).abs < 8 &&
              (chunk[:x_min] - last[:x_max]) < 20 &&
              (chunk[:x_min] - last[:x_max]) > -5 &&
              !last[:text].strip.end_with?(":")

            last[:text] += " " + chunk[:text]
            last[:x_max] = chunk[:x_max]
            last[:y_min] = [last[:y_min], chunk[:y_min]].min
            last[:y_max] = [last[:y_max], chunk[:y_max]].max
          else
            merged << chunk
          end
        end
      end
      merged
    end
  end
end
