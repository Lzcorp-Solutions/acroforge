# frozen_string_literal: true

require "optparse"
require "yaml"
require "json"
require_relative "../acroforge"

module AcroForge
  module CLI
    EXIT_OK = 0
    EXIT_USER_ERROR = 1
    EXIT_VALIDATION_ERROR = 2
    EXIT_INTERNAL_ERROR = 3

    SUBCOMMANDS = %w[fields schema relabel compile bootstrap annotate prepare version help].freeze

    module_function

    def run(argv)
      argv = argv.dup
      sub = argv.shift
      return print_help(argv) if sub.nil? || sub == "help"
      return print_version if sub == "version"

      unless SUBCOMMANDS.include?(sub)
        warn "acroforge: unknown subcommand #{sub.inspect}. Try `acroforge help`."
        return EXIT_USER_ERROR
      end

      send("cmd_#{sub}", argv)
    rescue AcroForge::ValidationError, AcroForge::RelabelError => e
      warn "acroforge: #{e.message}"
      EXIT_VALIDATION_ERROR
    rescue Errno::ENOENT, ArgumentError => e
      warn "acroforge: #{e.message}"
      EXIT_USER_ERROR
    rescue => e
      warn "acroforge: internal error (#{e.class}): #{e.message}"
      EXIT_INTERNAL_ERROR
    end

    def print_version
      puts AcroForge::VERSION
      EXIT_OK
    end

    def print_help(_)
      puts <<~HELP
        acroforge: PDF AcroForm engine + relabeler

        Usage:
          acroforge fields <pdf>           [--json]
          acroforge schema infer <pdf>     [--out schema.yml] [--sections a,b,c] [-v]
          acroforge schema merge <mapping.yml> [--schema schema.yml] [--out schema.yml]
          acroforge relabel propose <pdf>  [--out mapping.yml] [--schema schema.yml] [--merge|--overwrite] [-v]
          acroforge relabel apply <pdf> <mapping.yml> [--annotate[=PATH]] [-v]
          acroforge compile <pdf>          [--schema schema.yml] [--out normalized.pdf | --overwrite]
          acroforge bootstrap <pdf>        [--schema-out s.yml] [--mapping-out m.yml] [-v]
          acroforge annotate <pdf>         [--mapping mapping.yml] [--out annotated.pdf]
          acroforge prepare <pdf>          [--out prepared.pdf] [--schema schema.yml]
          acroforge version
          acroforge help

        Pass -v or --verbose to bootstrap, schema infer, relabel propose, and
        relabel apply to see the engine's per-field reasoning on stdout.
      HELP
      EXIT_OK
    end

    # Run `block` with $stdout redirected to /dev/null, unless `verbose:` is true.
    # Used to suppress the engine's per-field chatter during normal CLI runs.
    def silenced(verbose: false)
      return yield if verbose
      orig = $stdout
      null = File.open(File::NULL, "w")
      $stdout = null
      begin
        yield
      ensure
        $stdout = orig
        null.close
      end
    end

    def summarize_propose(result)
      total = result[:total]
      mapped = result[:mapped]
      out = result[:out_path]
      if total.zero?
        puts "Wrote #{out}: no AcroForm fields found in the PDF."
      elsif mapped == total
        puts "Wrote #{out}: #{mapped} of #{total} fields proposed."
      else
        puts "Wrote #{out}: #{mapped} of #{total} fields proposed; #{total - mapped} need manual review."
      end
    end

    def summarize_apply(result, pdf)
      parts = ["#{result[:renamed]} renamed"]
      parts << "#{result[:disambiguated]} disambiguated" if result[:disambiguated] > 0
      parts << "#{result[:skipped_null]} skipped (no key)" if result[:skipped_null] > 0
      parts << "#{result[:stale]} stale" if result[:stale] > 0
      puts "Applied to #{pdf}: #{parts.join(", ")}."
    end

    def cmd_fields(argv)
      json = false
      OptionParser.new { |o| o.on("--json") { json = true } }.parse!(argv)
      pdf = argv.shift
      raise ArgumentError, "usage: acroforge fields <pdf> [--json]" unless pdf
      raise Errno::ENOENT, pdf unless File.exist?(pdf)

      fields = AcroForge::Engine.new(pdf).fields

      if json
        puts JSON.pretty_generate(fields)
      elsif fields.empty?
        puts "No AcroForm fields found in #{pdf}."
      else
        print_fields_table(fields)
      end
      EXIT_OK
    end

    def print_fields_table(fields)
      headers = ["NAME", "TYPE", "ALTERNATE NAME"]
      rows = fields.map { |f| [f[:name].to_s, f[:type].to_s, format_alternate_name(f[:alternate_name])] }
      widths = headers.each_with_index.map { |h, i| ([h] + rows.map { |r| r[i] }).map(&:length).max }
      ([headers] + rows).each do |row|
        puts row.each_with_index.map { |cell, i| cell.ljust(widths[i]) }.join("  ").rstrip
      end
    end

    def format_alternate_name(alt)
      case alt
      when nil then "—"
      when Hash then "{#{alt.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")}}"
      else alt.to_s
      end
    end

    def cmd_schema(argv)
      action = argv.shift
      case action
      when "infer"
        out = "schema.yml"
        sections = []
        verbose = false
        OptionParser.new do |opts|
          opts.on("--out PATH") { |v| out = v }
          opts.on("--sections LIST") { |v| sections = v.split(",").map(&:strip) }
          opts.on("-v", "--verbose") { verbose = true }
        end.parse!(argv)
        pdf = argv.shift
        raise ArgumentError, "missing <pdf> argument" if pdf.nil?
        raise Errno::ENOENT, pdf unless File.exist?(pdf)

        schema = silenced(verbose: verbose) { AcroForge::Schema.infer(pdf, sections: sections) }
        AcroForge::Schema.dump(schema, out)
        count = schema.size
        puts "Wrote #{out}: #{count} canonical key#{"s" unless count == 1} inferred."
        EXIT_OK
      when "merge"
        schema_path = "schema.yml"
        out = nil
        OptionParser.new do |opts|
          opts.on("--schema PATH") { |v| schema_path = v }
          opts.on("--out PATH") { |v| out = v }
        end.parse!(argv)
        mapping_path = argv.shift
        raise ArgumentError, "missing <mapping.yml> argument" if mapping_path.nil?
        raise Errno::ENOENT, mapping_path unless File.exist?(mapping_path)
        out ||= schema_path

        existing = File.exist?(schema_path) ? AcroForge::Schema.load(schema_path) : {}
        keys_before = existing.keys.to_set
        variations_before = existing.each_with_object({}) do |(k, v), acc|
          acc[k] = (v.is_a?(Hash) ? (v[:variations] || []) : []).to_set
        end

        mapping = YAML.load_file(mapping_path) || {}
        merged = AcroForge::Schema.merge(existing, mapping.reject { |k, _| k.to_s.start_with?("_") })
        AcroForge::Schema.dump(merged, out)

        added = (merged.keys.to_set - keys_before).size
        updated = merged.keys.count do |k|
          next false unless keys_before.include?(k)
          (merged[k][:variations] || []).to_set != (variations_before[k] || Set.new)
        end
        summarize_schema_merge(out, added, updated)
        EXIT_OK
      else
        warn "acroforge: unknown schema action #{action.inspect}"
        EXIT_USER_ERROR
      end
    end

    def summarize_schema_merge(out, added, updated)
      parts = []
      parts << "#{added} new key#{"s" unless added == 1} added" if added > 0
      parts << "#{updated} existing key#{"s" unless updated == 1} updated" if updated > 0
      detail = parts.empty? ? "no changes" : parts.join(", ")
      puts "Merged into #{out}: #{detail}."
    end

    def cmd_relabel(argv)
      action = argv.shift
      case action
      when "propose"
        out = "mapping.yml"
        schema_path = nil
        mode = :merge
        verbose = false
        OptionParser.new do |opts|
          opts.on("--out PATH") { |v| out = v }
          opts.on("--schema PATH") { |v| schema_path = v }
          opts.on("--merge") { mode = :merge }
          opts.on("--overwrite") { mode = :overwrite }
          opts.on("-v", "--verbose") { verbose = true }
        end.parse!(argv)
        pdf = argv.shift
        raise ArgumentError, "missing <pdf> argument" if pdf.nil?
        raise Errno::ENOENT, pdf unless File.exist?(pdf)

        schema = schema_path ? AcroForge::Schema.load(schema_path) : {}
        result = silenced(verbose: verbose) do
          AcroForge::Relabeler.propose(pdf, out: out, schema: schema, mode: mode)
        end
        summarize_propose(result)
        EXIT_OK
      when "apply"
        verbose = false
        # `annotate_out` tracks three states:
        #   false       -> --annotate not passed; no annotation
        #   true        -> --annotate passed without value; use default path
        #   "some/path" -> --annotate=path passed explicitly
        annotate_out = false
        OptionParser.new do |opts|
          opts.on("-v", "--verbose") { verbose = true }
          opts.on("--annotate [PATH]", "Also write an annotated review PDF (default: <source>_annotated.pdf)") do |v|
            annotate_out = v || true
          end
        end.parse!(argv)
        pdf = argv.shift
        mapping = argv.shift
        raise ArgumentError, "missing arguments: expected <pdf> <mapping.yml>" if pdf.nil? || mapping.nil?
        raise Errno::ENOENT, pdf unless File.exist?(pdf)
        raise Errno::ENOENT, mapping unless File.exist?(mapping)

        # Annotation runs BEFORE the rename so the badges show
        # original_field_name -> proposed_key. After the rename, the mapping's
        # PDF field names no longer match the file, so post-rename annotation
        # would render every entry as "missing in mapping" -- useless.
        annotate_path = nil
        if annotate_out
          annotate_path = (annotate_out == true) ? default_annotated_path(pdf) : annotate_out
          silenced(verbose: verbose) do
            AcroForge::Annotator.annotate(pdf, out: annotate_path, mapping: mapping)
          end
        end

        result = silenced(verbose: verbose) { AcroForge::Relabeler.apply!(pdf, mapping) }
        summarize_apply(result, pdf)
        puts "Wrote #{annotate_path}: review snapshot of the mapping plan." if annotate_path
        EXIT_OK
      else
        warn "acroforge: unknown relabel action #{action.inspect}"
        EXIT_USER_ERROR
      end
    end

    def cmd_compile(argv)
      schema_path = nil
      out = nil
      overwrite = false
      OptionParser.new do |opts|
        opts.on("--schema PATH") { |v| schema_path = v }
        opts.on("--out PATH", "Write the normalized PDF to PATH") { |v| out = v }
        opts.on("--overwrite", "Write the normalized PDF back over the input PDF in place") { overwrite = true }
      end.parse!(argv)
      pdf = argv.shift
      raise ArgumentError, "missing <pdf> argument" if pdf.nil?
      raise ArgumentError, "--out and --overwrite are mutually exclusive" if out && overwrite
      raise Errno::ENOENT, pdf unless File.exist?(pdf)

      schema = schema_path ? AcroForge::Schema.load(schema_path) : {}
      out ||= pdf if overwrite

      engine = AcroForge::Engine.new(pdf, schema: schema, normalized_dir: out ? File.dirname(out) : nil)
      result = engine.compile!(normalized_out: out)
      puts "Mapped: #{result[:mapped].size}, Unmapped: #{result[:unmapped].size}"
      where = overwrite ? "#{engine.normalized_path} (in place)" : engine.normalized_path
      puts "Wrote #{where}: normalized template."
      EXIT_OK
    end

    def cmd_prepare(argv)
      out = nil
      schema_path = nil
      OptionParser.new do |opts|
        opts.on("--out PATH") { |v| out = v }
        opts.on("--schema PATH") { |v| schema_path = v }
      end.parse!(argv)
      pdf = argv.shift
      raise ArgumentError, "missing <pdf> argument" if pdf.nil?
      raise Errno::ENOENT, pdf unless File.exist?(pdf)
      raise Errno::ENOENT, schema_path if schema_path && !File.exist?(schema_path)

      schema = schema_path ? AcroForge::Schema.load(schema_path) : {}
      result = silenced(verbose: false) do
        AcroForge::Preparer.prepare!(pdf, out: out, schema: schema)
      end
      summarize_prepare(result, pdf, out)
      EXIT_OK
    end

    def summarize_prepare(result, in_path, explicit_out)
      target = result[:out_path]
      where = (target == in_path) ? "in place" : "to #{target}"
      if result[:duplicate_groups].zero?
        puts "Nothing to do: #{in_path} has no duplicate field names."
      else
        parts = ["#{result[:renamed]} duplicates renamed"]
        parts << "#{result[:skipped]} skipped (no heuristic proposal)" if result[:skipped] > 0
        puts "Prepared #{where}: #{result[:duplicate_groups]} duplicate groups, #{parts.join(", ")}."
      end
    end

    def cmd_annotate(argv)
      out = nil
      mapping_path = nil
      OptionParser.new do |opts|
        opts.on("--out PATH") { |v| out = v }
        opts.on("--mapping PATH") { |v| mapping_path = v }
      end.parse!(argv)
      pdf = argv.shift
      raise ArgumentError, "missing <pdf> argument" if pdf.nil?
      raise Errno::ENOENT, pdf unless File.exist?(pdf)
      raise Errno::ENOENT, mapping_path if mapping_path && !File.exist?(mapping_path)

      out ||= default_annotated_path(pdf)
      result = AcroForge::Annotator.annotate(pdf, out: out, mapping: mapping_path)
      summarize_annotate(result, mapping_path)
      EXIT_OK
    end

    def default_annotated_path(pdf)
      base = File.basename(pdf, ".*")
      File.join(File.dirname(pdf), "#{base}_annotated.pdf")
    end

    def summarize_annotate(result, mapping_path)
      if mapping_path
        parts = ["#{result[:mapped]} mapped"]
        parts << "#{result[:unmapped]} no key" if result[:unmapped] > 0
        parts << "#{result[:missing]} not in mapping" if result[:missing] > 0
        puts "Wrote #{result[:out_path]}: #{result[:annotated]} fields annotated (#{parts.join(", ")})."
      else
        puts "Wrote #{result[:out_path]}: #{result[:annotated]} fields annotated."
      end
    end

    def cmd_bootstrap(argv)
      schema_out = "schema.yml"
      mapping_out = "mapping.yml"
      verbose = false
      OptionParser.new do |opts|
        opts.on("--schema-out PATH") { |v| schema_out = v }
        opts.on("--mapping-out PATH") { |v| mapping_out = v }
        opts.on("-v", "--verbose") { verbose = true }
      end.parse!(argv)
      pdf = argv.shift
      raise ArgumentError, "missing <pdf> argument" if pdf.nil?
      raise Errno::ENOENT, pdf unless File.exist?(pdf)

      # Run the engine ONCE. Schema.infer and Relabeler.propose both accept
      # an `engine:` kwarg so they reuse the same compile pass instead of
      # each running their own (which would print the verbose chatter twice).
      require "tmpdir"
      Dir.mktmpdir do |tmp|
        engine = AcroForge::Engine.new(pdf, normalized_dir: tmp)
        silenced(verbose: verbose) { engine.compile!(announce_output: false) }

        schema = AcroForge::Schema.infer(pdf, engine: engine)
        AcroForge::Schema.dump(schema, schema_out)
        count = schema.size
        puts "Wrote #{schema_out}: #{count} canonical key#{"s" unless count == 1} inferred."

        result = AcroForge::Relabeler.propose(pdf, out: mapping_out, schema: schema, mode: :overwrite, engine: engine)
        summarize_propose(result)
      end
      EXIT_OK
    end
  end
end
