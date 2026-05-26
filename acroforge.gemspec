# frozen_string_literal: true

require_relative "lib/acroforge/version"

Gem::Specification.new do |spec|
  spec.name = "acroforge"
  spec.version = AcroForge::VERSION
  spec.authors = ["Maxwell Nana Forson"]
  spec.email = ["nanaforson@gmail.com"]

  spec.summary = "PDF AcroForm engine with heuristic-assisted field relabeling."
  spec.description = "Compile, fill, and relabel garbage-named AcroForm PDFs through a spatial heuristic and a human-reviewed mapping file."
  spec.homepage = "https://github.com/Lzcorp-Solutions/acroforge"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7"

  spec.metadata["homepage_uri"]      = spec.homepage
  spec.metadata["source_code_uri"]   = "#{spec.homepage}/tree/main"
  spec.metadata["bug_tracker_uri"]   = "#{spec.homepage}/issues"
  spec.metadata["changelog_uri"]     = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://lzcorp-solutions.github.io/acroforge/"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ docs/ .git .github appveyor Gemfile]) ||
        %w[.rspec .standard.yml .rubocop.yml Gemfile.lock].include?(f)
    end
  end

  spec.bindir = "exe"
  spec.executables = ["acroforge"]
  spec.require_paths = ["lib"]

  spec.add_dependency "hexapdf", "~> 1.0"
end
