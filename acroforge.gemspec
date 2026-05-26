# frozen_string_literal: true

require_relative "lib/acroforge/version"

Gem::Specification.new do |spec|
  spec.name = "acroforge"
  spec.version = AcroForge::VERSION
  spec.authors = ["Petra"]
  spec.email = ["hello@cropdoor.com"]

  spec.summary = "PDF AcroForm engine with heuristic-assisted field relabeling."
  spec.description = "Compile, fill, and relabel garbage-named AcroForm PDFs through a spatial heuristic and a human-reviewed mapping file."
  spec.homepage = "https://github.com/petra/acroforge"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end

  spec.bindir = "exe"
  spec.executables = ["acroforge"]
  spec.require_paths = ["lib"]

  spec.add_dependency "hexapdf", "~> 1.0"
end
