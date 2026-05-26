# frozen_string_literal: true

module FormStencil
  module Schema
    module_function

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
