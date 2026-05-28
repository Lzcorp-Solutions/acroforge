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

  it "relabel propose --schema honours an existing schema during compile" do
    schema_path = File.join(@tmp, "schema.yml")
    mapping_path = File.join(@tmp, "mapping.yml")
    File.write(schema_path, {full_name: {type: :string, variations: ["Customer Name"]}}.to_yaml)

    code, _, _ = capture do
      described_class.run(["relabel", "propose", garbage_fixture,
        "--schema", schema_path, "--out", mapping_path])
    end
    expect(code).to eq(0)
    expect(File.exist?(mapping_path)).to be true
  end

  it "relabel propose --overwrite replaces any prior mapping at the out path" do
    out_path = File.join(@tmp, "mapping.yml")
    File.write(out_path, "stale: { key: should_disappear }\n")

    code, _, _ = capture do
      described_class.run(["relabel", "propose", garbage_fixture,
        "--out", out_path, "--overwrite"])
    end
    expect(code).to eq(0)
    data = YAML.load_file(out_path)
    expect(data).not_to have_key("stale")
  end

  it "schema merge folds a mapping's keys into an existing schema" do
    schema_path = File.join(@tmp, "schema.yml")
    mapping_path = File.join(@tmp, "mapping.yml")
    File.write(schema_path, {full_name: {type: :string}}.to_yaml)
    File.write(mapping_path, {
      "page0_field6" => {"key" => "email", "type" => "email", "meta" => {"raw_label" => "Email Address"}}
    }.to_yaml)

    code, out, _ = capture { described_class.run(["schema", "merge", mapping_path, "--schema", schema_path]) }
    expect(code).to eq(0)
    expect(out).to match(/added|updated/i)

    merged = AcroForge::Schema.load(schema_path)
    expect(merged.keys).to include(:full_name, :email)
  end

  it "relabel apply rewrites field[:T] in place against a mapping file" do
    out_pdf = File.join(@tmp, "garbage.pdf")
    require "fileutils"
    FileUtils.cp(garbage_fixture, out_pdf)

    mapping_path = File.join(@tmp, "mapping.yml")
    code, _, _ = capture { described_class.run(["relabel", "propose", out_pdf, "--out", mapping_path]) }
    expect(code).to eq(0)

    require "hexapdf"
    names_before = HexaPDF::Document.open(out_pdf).acro_form.each_field.map(&:full_field_name)

    code, _, _ = capture { described_class.run(["relabel", "apply", out_pdf, mapping_path]) }
    expect(code).to eq(0)

    # Some fields should have been renamed (unmapped ones may legitimately stay).
    names_after = HexaPDF::Document.open(out_pdf).acro_form.each_field.map(&:full_field_name)
    expect(names_after).not_to eq(names_before)
    expect(names_after.count { |n| n.match?(/\Apage\d/) }).to be < names_before.count { |n| n.match?(/\Apage\d/) }
  end
end
