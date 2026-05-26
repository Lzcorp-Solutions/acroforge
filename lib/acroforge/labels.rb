# frozen_string_literal: true

require_relative "constants"

module AcroForge
  # Cleans up human-readable labels extracted from PDFs.
  #
  # PDF text extraction often produces broken word fragments (e.g. a ligature
  # like "fi" gets split, producing "Tax Identi fi cation No.") and labels
  # rendered in different casing conventions across vendors (ALL UPPER, mixed,
  # sentence case). This module normalizes both: it fixes the typo fragments
  # using Constants::TYPO_PHRASE_REPLACEMENTS and converts the result to
  # consistent title case. Used by Engine, Schema, and Relabeler so the same
  # corrections appear in the verbose log, schema variations, and mapping meta.
  module Labels
    module_function

    # Words that conventionally stay lowercase inside a title (except when
    # they're the first or last word).
    TITLE_CASE_CONNECTORS = %w[
      a an the and but or nor for so yet
      of at by in on to up from with as vs
    ].to_set

    def humanize(label)
      return label unless label.is_a?(String) && !label.empty?

      result = fix_typos(label)
      result = title_case(result)
      result.gsub(/\s+/, " ").strip
    end

    # Fix snake_case typo patterns from Constants::TYPO_PHRASE_REPLACEMENTS in
    # the human-readable label too. "Identi fi cation" -> "Identification".
    def fix_typos(label)
      result = label.dup
      Constants::TYPO_PHRASE_REPLACEMENTS.each do |bad, good|
        parts = bad.split("_").reject(&:empty?).map { |p| Regexp.escape(p) }
        next if parts.empty?
        pattern = /\b#{parts.join('\s+')}\b/i
        result = result.gsub(pattern) do |match|
          replacement = good.tr("_", " ")
          if match[0] == match[0].upcase
            replacement[0].upcase + (replacement[1..] || "")
          else
            replacement
          end
        end
      end
      result
    end

    # Convert a label to standard title case:
    #   - First and last words always capitalized
    #   - Conventional connectors (of, the, to, ...) lowercased mid-label
    #   - All other words capitalized on the first letter
    #   - Short all-uppercase tokens (<= 3 chars) preserved as acronyms
    #     (GHC, DOB, PDF, ID stay as-is; "DDMMYYYY" also preserved as a format)
    #   - A word immediately following an opening "(" or "[" is treated as
    #     starting a fresh title, so its first letter capitalizes even if it
    #     would otherwise be a connector ("(For Disbursement)" not "(for ...)")
    def title_case(text)
      words = text.split(/(\s+)/)  # preserve whitespace between words
      content_indices = words.each_index.select { |i| words[i].match?(/\S/) }
      first_idx = content_indices.first
      last_idx = content_indices.last

      words.each_with_index.map do |word, i|
        next word if word.match?(/^\s*$/)

        if acronym?(word)
          word
        elsif i == first_idx || i == last_idx || word.start_with?("(", "[", '"', "'")
          capitalize_first(word)
        elsif TITLE_CASE_CONNECTORS.include?(strip_punct(word).downcase)
          word.downcase
        else
          capitalize_first(word)
        end
      end.join
    end

    # Treat as an acronym if it's all uppercase AND short (<= 3 chars), OR
    # if it has 4+ all-upper letters AND looks like a format/code rather than
    # a word (e.g., "DDMMYYYY"). Mixed letters & digits also count.
    def acronym?(word)
      core = strip_punct(word)
      return false if core.empty?
      return true if core.length <= 3 && core == core.upcase && core.match?(/[A-Z]/)
      # Longer all-upper tokens: keep as acronym only if they contain digits
      # (e.g. "DDMMYYYY", "ID2024") or repeat a pattern that suggests format code.
      return true if core.length >= 4 && core == core.upcase && core.match?(/\d|^([A-Z])\1+/)
      false
    end

    def strip_punct(word)
      word.gsub(/[[:punct:]]/, "")
    end

    def capitalize_first(word)
      return word if word.empty?
      # Preserve trailing/embedded punctuation; only fix the casing of the
      # alphabetic part.
      word.sub(/^([[:punct:]]*)([A-Za-z])(.*)$/) do
        prefix = ::Regexp.last_match(1)
        first = ::Regexp.last_match(2).upcase
        rest = ::Regexp.last_match(3).downcase
        "#{prefix}#{first}#{rest}"
      end
    end
  end
end
