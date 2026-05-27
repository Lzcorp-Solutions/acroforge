# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in acroforge.gemspec
gemspec

gem "irb"
gem "rake", "~> 13.0"

gem "rspec", "~> 3.0"

# Modern standard / rubocop transitively pull in erb >= 6, which requires
# Ruby >= 3.2. Gate the whole chain on Ruby 3.2+ so the gem itself stays
# installable on the Rubies declared in the gemspec (>= 2.7).
gem "standard", "~> 1.3", install_if: -> { RUBY_VERSION >= "3.2" }
