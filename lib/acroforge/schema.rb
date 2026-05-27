# frozen_string_literal: true

require "yaml"
require "json"
require_relative "engine"
require_relative "labels"

module AcroForge
  module Schema
    module_function

    def load(path)
      raw = case File.extname(path).downcase
      when ".yml", ".yaml"
        # safe_load_file was added in Psych 4 (Ruby 3.1+); safe_load(File.read)
        # keeps the gem usable on Ruby 2.7 as the gemspec advertises.
        YAML.safe_load(File.read(path), permitted_classes: [Symbol], aliases: true) # standard:disable Style/YAMLFileRead
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

    # Infer a schema from a PDF.
    #
    # If `engine:` is given, the caller has already compiled an engine and
    # we use its proposals directly. This lets callers (notably the CLI's
    # `bootstrap` subcommand) avoid a redundant second compile when they
    # also want to call Relabeler.propose on the same PDF.
    def infer(pdf_path, sections: [], engine: nil)
      return aggregate_proposals(engine.field_proposals) if engine

      require "tmpdir"
      Dir.mktmpdir do |tmp|
        e = AcroForge::Engine.new(pdf_path, sections: sections, normalized_dir: tmp)
        e.compile!
        aggregate_proposals(e.field_proposals)
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

    # Thin delegator. The real implementation lives in AcroForge::Labels so
    # the Engine can apply it at the source (right after the spatial heuristic
    # picks a label) without creating a circular require between engine.rb
    # and schema.rb.
    def humanize_label(label)
      AcroForge::Labels.humanize(label)
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

    # Merge a mapping file's hand-reviewed decisions back into a schema.
    # Each non-null mapping entry contributes a canonical key (stripped of
    # any _N collision suffix), its type, and its raw_label as a variation.
    # Existing schema entries keep their type but gain new variations;
    # missing entries are created. Returns the merged schema hash.
    def merge(schema, mapping_entries)
      result = schema.each_with_object({}) do |(k, v), out|
        out[k] = v.is_a?(Hash) ? v.dup.tap { |d| d[:variations] = (d[:variations] || []).dup } : v
      end

      mapping_entries.each do |pdf_field_name, entry|
        next if pdf_field_name.to_s.start_with?("_")
        next unless entry.is_a?(Hash)

        key_str = entry["key"]
        next if key_str.nil? || key_str.to_s.empty?

        # Strip the _N collision suffix the engine appends when multiple
        # fields map to the same canonical key (full_name_1, full_name_2).
        canonical = key_str.to_s.sub(/_\d+\z/, "").to_sym

        type_str = entry["type"]
        type_sym = type_str.is_a?(String) ? type_str.to_sym : type_str

        result[canonical] ||= {type: type_sym || :string, variations: []}
        # Don't overwrite an existing type unless one is actually given
        result[canonical][:type] = type_sym if type_sym

        raw_label = entry.dig("meta", "raw_label")
        if raw_label && !raw_label.to_s.empty?
          variations = result[canonical][:variations] ||= []
          variations << raw_label.to_s unless variations.include?(raw_label.to_s)
        end
      end

      result
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
