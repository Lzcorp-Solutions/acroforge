# frozen_string_literal: true

require_relative "lib/form_stencil/version"

Gem::Specification.new do |spec|
  spec.name = "form_stencil"
  spec.version = FormStencil::VERSION
  spec.authors = ["Petra"]
  spec.email = ["hello@cropdoor.com"]

  spec.summary = "PDF AcroForm engine with heuristic-assisted field relabeling."
  spec.description = "Compile, fill, and relabel garbage-named AcroForm PDFs through a spatial heuristic and a human-reviewed mapping file."
  spec.homepage = "https://github.com/petra/form_stencil"
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
  spec.executables = ["form_stencil"]
  spec.require_paths = ["lib"]

  spec.add_dependency "hexapdf", "~> 1.0"
end
