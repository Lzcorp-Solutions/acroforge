# frozen_string_literal: true

require "tmpdir"
require "hexapdf"
require_relative "engine"

module AcroForge
  # Resolves PDF-internal naming conflicts so they don't get in the way of
  # the human-review workflow.
  #
  # Some PDFs have multiple AcroForm fields sharing the same :T name (e.g.,
  # three separate fields all literally named "date"). YAML mappings can't
  # represent that cleanly — the engine has to fall back to synthetic
  # "date#1", "date#2" suffixes. Preparer mutates the PDF up front to give
  # each duplicate a unique name based on the spatial heuristic's proposal,
  # so subsequent commands (bootstrap, relabel apply) see a clean PDF.
  #
  # Single responsibility: rename duplicate-named fields. Fields with
  # already-unique names are never touched, regardless of what the heuristic
  # proposes for them.
  module Preparer
    module_function

    def prepare!(pdf_path, out: nil, schema: {})
      out ||= pdf_path

      proposals = nil
      Dir.mktmpdir do |tmp|
        engine = AcroForge::Engine.new(pdf_path, schema: schema, normalized_dir: tmp)
        engine.compile!
        proposals = engine.field_proposals
      end

      # Group proposals by their ORIGINAL field name (strip any #N suffix).
      # Any name appearing more than once is a duplicate that needs resolving.
      grouped = proposals.group_by { |p| base_name(p[:pdf_field_name]) }
      duplicates = grouped.select { |_, occs| occs.length > 1 }

      if duplicates.empty?
        # Nothing to do. Don't rewrite the file when out == in.
        FileUtils.cp(pdf_path, out) if out != pdf_path
        return {duplicate_groups: 0, renamed: 0, skipped: 0, out_path: out}
      end

      doc = HexaPDF::Document.open(pdf_path)
      form = doc.acro_form(create: false)
      raise RelabelError, "PDF has no AcroForm: #{pdf_path}" unless form

      field_index = AcroForge::Engine.field_index(form)
      # Names already in use by NON-duplicate fields; we can't collide with them.
      reserved = field_index.keys.reject { |k| k.include?("#") }.to_set
      duplicates.each_key { |base| reserved.delete(base) }

      renamed = 0
      skipped = 0

      duplicates.each_value do |occurrences|
        occurrences.each do |proposal|
          field = field_index[proposal[:pdf_field_name]]
          unless field
            skipped += 1
            next
          end

          proposed = proposal[:canonical_key]
          unless proposed
            skipped += 1
            next
          end

          target = unique_target(proposed.to_s, reserved)
          reserved.add(target)
          field[:T] = target
          field[:TU] = target
          renamed += 1
        end
      end

      doc.write(out)

      {
        duplicate_groups: duplicates.size,
        renamed: renamed,
        skipped: skipped,
        out_path: out
      }
    end

    def base_name(synthetic_name)
      synthetic_name.to_s.sub(/#\d+\z/, "")
    end

    def unique_target(target, reserved)
      return target unless reserved.include?(target)
      counter = 1
      loop do
        candidate = "#{target}_#{counter}"
        return candidate unless reserved.include?(candidate)
        counter += 1
      end
    end
  end
end
