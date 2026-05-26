# frozen_string_literal: true

require "yaml"
require "json"

module FormStencil
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
