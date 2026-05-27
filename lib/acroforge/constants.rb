# frozen_string_literal: true

module AcroForge
  module Constants
    TYPO_PHRASE_REPLACEMENTS = {
      "identi_fi_cation" => "identification",
      "identi_cation" => "identification",
      "ide_ntity" => "identity",
      "contribu_on" => "contribution",
      "con_rmed" => "confirmed",
      "na_onal" => "national",
      "ocial" => "official",
      "modeof" => "mode_of",
      "modeofr" => "mode_of_r",
      "nameof" => "name_of"
    }.freeze

    # PDF text extraction returns Unicode quirks: ligatures (ﬁ instead of f+i),
    # fullwidth letters, curly quotes, etc. AllTextProcessor normalizes via
    # Unicode NFKC first, which handles most of the "compatibility" subset
    # automatically (ligatures, fullwidth, superscript digits, ...). NFKC
    # does NOT touch these characters — they're separate codepoints, not
    # compatibility decompositions — so we substitute them manually.
    UNICODE_REPLACEMENTS = {
      "\u{2018}" => "'",      # left single quote
      "\u{2019}" => "'",      # right single quote
      "\u{201A}" => "'",      # single low-9 quote
      "\u{201C}" => '"',      # left double quote
      "\u{201D}" => '"',      # right double quote
      "\u{201E}" => '"',      # double low-9 quote
      "\u{2013}" => "-",      # en dash
      "\u{2014}" => "-",      # em dash
      "\u{2010}" => "-",      # hyphen
      "\u{2011}" => "-",      # non-breaking hyphen
      "\u{2212}" => "-",      # minus sign
      "\u{00AD}" => "",       # soft hyphen (often invisible artifact)
      "\u{200B}" => "",       # zero-width space
      "\u{200C}" => "",       # zero-width non-joiner
      "\u{200D}" => "",       # zero-width joiner
      "\u{FEFF}" => "",       # zero-width no-break space (BOM)
      "\u{2026}" => "...",    # ellipsis
      "\u{2022}" => "*",      # bullet
      "\u{00B7}" => "*"       # middle dot used as bullet
    }.freeze
  end
end
