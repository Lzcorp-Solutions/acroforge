# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "stringio"
require "yaml"
require "acroforge/cli"

RSpec.describe AcroForge::CLI do
  let(:garbage_fixture) { File.expand_path("../fixtures/garbage_named.pdf", __dir__) }

  around do |example|
    Dir.mktmpdir do |tmp|
      @tmp = tmp
      example.run
    end
  end

  def capture
    out = StringIO.new
    err = StringIO.new
    orig_out, orig_err = $stdout, $stderr
    $stdout, $stderr = out, err
    code = yield
    [code, out.string, err.string]
  ensure
    $stdout, $stderr = orig_out, orig_err
  end

  it "version prints the version string and returns 0" do
    code, out, _ = capture { described_class.run(%w[version]) }
    expect(code).to eq(0)
    expect(out).to include(AcroForge::VERSION)
  end

  it "help with no args returns 0 and lists subcommands" do
    code, out, _ = capture { described_class.run(%w[help]) }
    expect(code).to eq(0)
    expect(out).to match(/schema|relabel|compile|bootstrap/)
  end

  it "unknown subcommand returns exit 1 and prints to stderr" do
    code, _, err = capture { described_class.run(%w[banana]) }
    expect(code).to eq(1)
    expect(err).to match(/unknown/i)
  end

  it "missing file returns exit 1" do
    code, _, err = capture { described_class.run(["relabel", "propose", "/nonexistent.pdf", "--out", "/tmp/x.yml"]) }
    expect(code).to eq(1)
    expect(err).to match(/not found|no such/i)
  end

  it "schema infer writes a schema YAML and returns 0" do
    out_path = File.join(@tmp, "schema.yml")
    code, _, _ = capture { described_class.run(["schema", "infer", garbage_fixture, "--out", out_path]) }
    expect(code).to eq(0)
    expect(File.exist?(out_path)).to be true
    data = YAML.load_file(out_path)
    expect(data).not_to be_empty
  end

  it "relabel propose writes a mapping YAML and returns 0" do
    out_path = File.join(@tmp, "mapping.yml")
    code, _, _ = capture { described_class.run(["relabel", "propose", garbage_fixture, "--out", out_path]) }
    expect(code).to eq(0)
    data = YAML.load_file(out_path)
    expect(data).to include("_meta")
  end
end
