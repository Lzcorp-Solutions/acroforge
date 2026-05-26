# frozen_string_literal: true

require "optparse"
require_relative "../acroforge"

module AcroForge
  module CLI
    EXIT_OK = 0
    EXIT_USER_ERROR = 1
    EXIT_VALIDATION_ERROR = 2
    EXIT_INTERNAL_ERROR = 3

    SUBCOMMANDS = %w[schema relabel compile bootstrap version help].freeze

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
          acroforge schema infer <pdf>     [--out schema.yml] [--sections a,b,c] [-v]
          acroforge relabel propose <pdf>  [--out mapping.yml] [--schema schema.yml] [--merge|--overwrite] [-v]
          acroforge relabel apply <pdf> <mapping.yml> [-v]
          acroforge compile <pdf>          [--schema schema.yml]
          acroforge bootstrap <pdf>        [--schema-out s.yml] [--mapping-out m.yml] [-v]
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
      else
        warn "acroforge: unknown schema action #{action.inspect}"
        EXIT_USER_ERROR
      end
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
        OptionParser.new do |opts|
          opts.on("-v", "--verbose") { verbose = true }
        end.parse!(argv)
        pdf = argv.shift
        mapping = argv.shift
        raise ArgumentError, "missing arguments: expected <pdf> <mapping.yml>" if pdf.nil? || mapping.nil?
        raise Errno::ENOENT, pdf unless File.exist?(pdf)
        raise Errno::ENOENT, mapping unless File.exist?(mapping)

        result = silenced(verbose: verbose) { AcroForge::Relabeler.apply!(pdf, mapping) }
        summarize_apply(result, pdf)
        EXIT_OK
      else
        warn "acroforge: unknown relabel action #{action.inspect}"
        EXIT_USER_ERROR
      end
    end

    def cmd_compile(argv)
      schema_path = nil
      OptionParser.new do |opts|
        opts.on("--schema PATH") { |v| schema_path = v }
      end.parse!(argv)
      pdf = argv.shift
      raise ArgumentError, "missing <pdf> argument" if pdf.nil?
      raise Errno::ENOENT, pdf unless File.exist?(pdf)

      schema = schema_path ? AcroForge::Schema.load(schema_path) : {}
      require "tmpdir"
      Dir.mktmpdir do |tmp|
        engine = AcroForge::Engine.new(pdf, schema: schema, normalized_dir: tmp)
        result = engine.compile!
        puts "Mapped: #{result[:mapped].size}, Unmapped: #{result[:unmapped].size}"
      end
      EXIT_OK
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
        silenced(verbose: verbose) { engine.compile! }

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
