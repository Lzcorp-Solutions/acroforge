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
          acroforge schema infer <pdf>     [--out schema.yml] [--sections a,b,c]
          acroforge relabel propose <pdf>  [--out mapping.yml] [--schema schema.yml] [--merge|--overwrite]
          acroforge relabel apply <pdf> <mapping.yml>
          acroforge compile <pdf>          [--schema schema.yml]
          acroforge bootstrap <pdf>        [--schema-out s.yml] [--mapping-out m.yml]
          acroforge version
          acroforge help
      HELP
      EXIT_OK
    end

    def cmd_schema(argv)
      action = argv.shift
      case action
      when "infer"
        out = "schema.yml"
        sections = []
        OptionParser.new do |opts|
          opts.on("--out PATH") { |v| out = v }
          opts.on("--sections LIST") { |v| sections = v.split(",").map(&:strip) }
        end.parse!(argv)
        pdf = argv.shift
        raise ArgumentError, "missing <pdf> argument" if pdf.nil?
        raise Errno::ENOENT, pdf unless File.exist?(pdf)

        schema = AcroForge::Schema.infer(pdf, sections: sections)
        AcroForge::Schema.dump(schema, out)
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
        OptionParser.new do |opts|
          opts.on("--out PATH") { |v| out = v }
          opts.on("--schema PATH") { |v| schema_path = v }
          opts.on("--merge") { mode = :merge }
          opts.on("--overwrite") { mode = :overwrite }
        end.parse!(argv)
        pdf = argv.shift
        raise ArgumentError, "missing <pdf> argument" if pdf.nil?
        raise Errno::ENOENT, pdf unless File.exist?(pdf)

        schema = schema_path ? AcroForge::Schema.load(schema_path) : {}
        AcroForge::Relabeler.propose(pdf, out: out, schema: schema, mode: mode)
        EXIT_OK
      when "apply"
        pdf = argv.shift
        mapping = argv.shift
        raise ArgumentError, "missing arguments: expected <pdf> <mapping.yml>" if pdf.nil? || mapping.nil?
        raise Errno::ENOENT, pdf unless File.exist?(pdf)
        raise Errno::ENOENT, mapping unless File.exist?(mapping)

        AcroForge::Relabeler.apply!(pdf, mapping)
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
      OptionParser.new do |opts|
        opts.on("--schema-out PATH") { |v| schema_out = v }
        opts.on("--mapping-out PATH") { |v| mapping_out = v }
      end.parse!(argv)
      pdf = argv.shift
      raise ArgumentError, "missing <pdf> argument" if pdf.nil?
      raise Errno::ENOENT, pdf unless File.exist?(pdf)

      schema = AcroForge::Schema.infer(pdf)
      AcroForge::Schema.dump(schema, schema_out)
      AcroForge::Relabeler.propose(pdf, out: mapping_out, schema: schema, mode: :overwrite)
      EXIT_OK
    end
  end
end
