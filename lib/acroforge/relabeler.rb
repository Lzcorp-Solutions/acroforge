# frozen_string_literal: true

require "yaml"
require "tmpdir"
require "time"
require_relative "engine"
require_relative "schema"
require_relative "version"

module AcroForge
  class RelabelError < StandardError; end

  module Relabeler
    module_function

    def propose(pdf_path, out:, schema: {}, mode: :merge)
      existing = (mode == :merge && File.exist?(out)) ? YAML.load_file(out) : nil

      Dir.mktmpdir do |tmp|
        engine = AcroForge::Engine.new(pdf_path, schema: schema, normalized_dir: tmp)
        engine.compile!

        sorted = engine.field_proposals.sort_by { |p| [p[:page], -p[:y], p[:x]] }
        entries = sorted.each_with_object({}) do |p, acc|
          acc[p[:pdf_field_name]] = build_entry(p, existing&.[](p[:pdf_field_name]))
        end

        File.write(out, render_yaml(pdf_path, entries))
      end
    end

    def build_entry(proposal, prior)
      proposed_key = proposal[:canonical_key]&.to_s
      proposed_type = infer_type(proposal).to_s

      key_value = prior&.key?("key") ? prior["key"] : proposed_key
      type_value = prior&.key?("type") ? prior["type"] : proposed_type

      meta = {
        "raw_label" => proposal[:raw_label],
        "confidence" => proposal[:confidence].to_s,
        "section" => proposal[:section]&.to_s,
        "page" => proposal[:page]
      }
      options = proposal[:options]&.transform_keys(&:to_s)
      meta["options"] = options if options

      {
        "key" => key_value,
        "type" => type_value,
        "meta" => meta
      }
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

    def render_yaml(pdf_path, entries)
      banner = {
        "_meta" => {
          "source_pdf" => pdf_path,
          "generated_at" => Time.now.utc.iso8601,
          "acroforge_version" => AcroForge::VERSION,
          "total_fields" => entries.size
        }
      }
      YAML.dump(banner.merge(entries))
    end
  end
end
