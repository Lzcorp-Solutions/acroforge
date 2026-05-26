# frozen_string_literal: true

require "yaml"
require "tmpdir"
require "time"
require "hexapdf"
require_relative "engine"
require_relative "schema"
require_relative "version"

module AcroForge
  class RelabelError < StandardError; end

  module Relabeler
    module_function

    KEY_REGEX = /\A[a-z][a-z0-9_]*\z/

    def apply!(pdf_path, mapping_path)
      data = YAML.load_file(mapping_path) || {}
      entries = data.reject { |k, _| k.to_s.start_with?("_") }

      validate!(entries)

      doc = HexaPDF::Document.open(pdf_path)
      form = doc.acro_form(create: false)
      raise RelabelError, "PDF has no AcroForm: #{pdf_path}" unless form

      renamed = 0
      disambiguated = 0
      skipped_null = 0
      stale = 0

      claimed = {}
      entries.each do |pdf_name, entry|
        key = entry["key"]
        if key.nil? || key.to_s.empty?
          skipped_null += 1
          next
        end

        field = form.field_by_name(pdf_name)
        unless field
          stale += 1
          warn "acroforge: stale entry #{pdf_name.inspect} not found in PDF (skipping)"
          next
        end

        target = key.to_s
        counter = 1
        while claimed.key?(target)
          target = "#{key}_#{counter}"
          counter += 1
        end
        disambiguated += 1 if target != key.to_s
        claimed[target] = true

        field[:T] = target
        field[:TU] = target
        renamed += 1
      end

      doc.write(pdf_path)

      {
        total: entries.size,
        renamed: renamed,
        disambiguated: disambiguated,
        skipped_null: skipped_null,
        stale: stale
      }
    end

    def validate!(entries)
      entries.each do |pdf_name, entry|
        raise RelabelError, "reserved sentinel: #{pdf_name.inspect}" if pdf_name.to_s.start_with?("_")
        key = entry["key"]
        next if key.nil? || key.to_s.empty?
        unless key.to_s.match?(KEY_REGEX)
          raise RelabelError, "invalid key #{key.inspect} for field #{pdf_name.inspect}: must match #{KEY_REGEX.inspect}"
        end
      end
    end

    # Write a mapping YAML proposing semantic names for every AcroForm field.
    #
    # If `engine:` is given, the caller has already compiled an engine and
    # we use its proposals directly (no second compile). This lets callers
    # like the CLI's `bootstrap` subcommand share one compile pass with
    # Schema.infer instead of running the engine twice.
    def propose(pdf_path, out:, schema: {}, mode: :merge, engine: nil)
      existing = (mode == :merge && File.exist?(out)) ? YAML.load_file(out) : nil

      proposals = if engine
        engine.field_proposals
      else
        Dir.mktmpdir do |tmp|
          e = AcroForge::Engine.new(pdf_path, schema: schema, normalized_dir: tmp)
          e.compile!
          e.field_proposals
        end
      end

      sorted = proposals.sort_by { |p| [p[:page], -p[:y], p[:x]] }
      entries = sorted.each_with_object({}) do |p, acc|
        acc[p[:pdf_field_name]] = build_entry(p, existing&.[](p[:pdf_field_name]))
      end

      File.write(out, render_yaml(pdf_path, entries))

      mapped = entries.values.count { |e| !e["key"].nil? && !e["key"].to_s.empty? }
      {
        total: entries.size,
        mapped: mapped,
        unmapped: entries.size - mapped,
        out_path: out
      }
    end

    def build_entry(proposal, prior)
      proposed_key = proposal[:canonical_key]&.to_s
      proposed_type = infer_type(proposal).to_s

      key_value = prior&.key?("key") ? prior["key"] : proposed_key
      type_value = prior&.key?("type") ? prior["type"] : proposed_type

      meta = {
        "raw_label" => AcroForge::Schema.humanize_label(proposal[:raw_label]),
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
