# frozen_string_literal: true

require "yaml"
require "json"
require_relative "engine"

module AcroForge
  module Schema
    module_function

    def load(path)
      raw = case File.extname(path).downcase
      when ".yml", ".yaml"
        YAML.safe_load_file(path, permitted_classes: [Symbol], aliases: true)
      when ".json"
        JSON.parse(File.read(path), symbolize_names: false)
      else
        raise ArgumentError, "unknown schema file extension: #{path.inspect}"
      end

      normalize(symbolize_schema(raw))
    end

    def dump(schema, path)
      stringified = stringify_schema(schema)
      case File.extname(path).downcase
      when ".yml", ".yaml"
        File.write(path, YAML.dump(stringified))
      when ".json"
        File.write(path, JSON.pretty_generate(stringified))
      else
        raise ArgumentError, "unknown schema file extension: #{path.inspect}"
      end
    end

    def symbolize_schema(raw_hash)
      return {} if raw_hash.nil? || raw_hash.empty?

      raw_hash.each_with_object({}) do |(key, value), out|
        out[key.to_sym] = symbolize_entry(value)
      end
    end

    def symbolize_entry(entry)
      return entry unless entry.is_a?(Hash)

      result = {}
      entry.each do |k, v|
        sym_k = k.to_sym
        result[sym_k] = case sym_k
        when :type
          v.is_a?(String) ? v.to_sym : v
        when :options
          if v.is_a?(Array)
            v.map { |item| item.is_a?(String) ? item.to_sym : item }
          else
            v
          end
        else
          v
        end
      end
      result
    end

    def stringify_schema(schema)
      schema.each_with_object({}) do |(key, value), out|
        out[key.to_s] = stringify_entry(value)
      end
    end

    def stringify_entry(entry)
      return entry unless entry.is_a?(Hash)

      result = {}
      entry.each do |k, v|
        str_k = k.to_s
        result[str_k] = case k.to_sym
        when :type
          v.is_a?(Symbol) ? v.to_s : v
        when :options
          if v.is_a?(Array)
            v.map { |item| item.is_a?(Symbol) ? item.to_s : item }
          else
            v
          end
        else
          v
        end
      end
      result
    end

    def infer(pdf_path, sections: [])
      require "tmpdir"
      Dir.mktmpdir do |tmp|
        engine = AcroForge::Engine.new(pdf_path, sections: sections, normalized_dir: tmp)
        engine.compile!
        aggregate_proposals(engine.field_proposals)
      end
    end

    def aggregate_proposals(proposals)
      proposals.each_with_object({}) do |p, schema|
        next if p[:canonical_key].nil?

        key = p[:canonical_key].to_sym
        schema[key] ||= {type: infer_type(p), variations: []}
        if p[:raw_label]
          cleaned = humanize_label(p[:raw_label])
          schema[key][:variations] << cleaned unless schema[key][:variations].include?(cleaned)
        end

        if p[:pdf_field_type] == :button && p[:options]
          schema[key][:options] = p[:options].keys.map(&:to_sym).uniq
        end
      end
    end

    # Apply the same typo corrections used for key sanitization back to the
    # human-readable label. PDF text extraction often splits words across
    # multiple text objects ("Tax Identi fi cation No."); this method derives
    # match patterns from Constants::TYPO_PHRASE_REPLACEMENTS and produces
    # the corrected human form ("Tax Identification No.").
    def humanize_label(label)
      return label unless label.is_a?(String) && !label.empty?

      result = label.dup
      AcroForge::Constants::TYPO_PHRASE_REPLACEMENTS.each do |bad, good|
        parts = bad.split("_").reject(&:empty?).map { |p| Regexp.escape(p) }
        next if parts.empty?
        pattern = /\b#{parts.join('\s+')}\b/i
        result = result.gsub(pattern) do |match|
          replacement = good.tr("_", " ")
          # Preserve initial capitalization so titles like "Identification" stay
          # capitalized in headings.
          if match[0] == match[0].upcase
            replacement[0].upcase + (replacement[1..] || "")
          else
            replacement
          end
        end
      end
      result.gsub(/\s+/, " ").strip
    end

    def infer_type(proposal)
      case proposal[:pdf_field_type]
      when :button
        ((proposal[:options]&.size || 0) > 1) ? :select : :boolean
      when :choice
        :select
      else
        label = proposal[:raw_label].to_s.downcase
        case label
        when /amount|salary|income|balance|fee|tier3/ then :money
        when /\bdate\b|birth|expiry|employed/ then :date
        when /email/ then :email
        when /years|tenor|number of|\bno\.?\b/ then :number
        else :string
        end
      end
    end

    def normalize(input)
      return {} if input.nil? || input.empty?

      input.each_with_object({}) do |(key, value), out|
        out[key] = case value
        when Array
          {type: :string, variations: value}
        when Hash
          value
        else
          raise ArgumentError, "Schema entry for #{key.inspect} must be an Array or Hash, got #{value.class}"
        end
      end
    end
  end
end
