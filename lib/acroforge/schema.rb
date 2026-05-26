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
        JSON.parse(File.read(path), symbolize_names: true)
      else
        raise ArgumentError, "unknown schema file extension: #{path.inspect}"
      end

      normalize(symbolize_top_level(raw))
    end

    def dump(schema, path)
      case File.extname(path).downcase
      when ".yml", ".yaml"
        File.write(path, YAML.dump(deep_stringify_symbols(schema)))
      when ".json"
        File.write(path, JSON.pretty_generate(deep_stringify_symbols(schema)))
      else
        raise ArgumentError, "unknown schema file extension: #{path.inspect}"
      end
    end

    def symbolize_top_level(hash)
      return {} if hash.nil?
      hash.each_with_object({}) { |(k, v), out| out[k.to_sym] = symbolize_inner(v) }
    end

    def symbolize_inner(value)
      case value
      when Hash then value.each_with_object({}) { |(k, v), out| out[k.to_sym] = symbolize_inner(v) }
      when Array then value.map { |v| symbolize_inner(v) }
      when String then value.start_with?(":") ? value[1..].to_sym : value
      else value
      end
    end

    def deep_stringify_symbols(value)
      case value
      when Symbol then ":#{value}"
      when Hash then value.each_with_object({}) { |(k, v), out| out[k.to_s] = deep_stringify_symbols(v) }
      when Array then value.map { |v| deep_stringify_symbols(v) }
      else value
      end
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
        if p[:raw_label] && !schema[key][:variations].include?(p[:raw_label])
          schema[key][:variations] << p[:raw_label]
        end

        if p[:pdf_field_type] == :button && p[:options]
          schema[key][:options] = p[:options].keys.map(&:to_sym).uniq
        end
      end
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
