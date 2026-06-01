# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in acroforge.gemspec
gemspec

gem "rake", "~> 13.0"

group :development, :test do
  gem "rspec", "~> 3.0"
  gem "simplecov", "~> 0.22", require: false
end

# Lint tooling is grouped so it can be skipped (BUNDLE_WITHOUT=lint) on
# CI's pre-3.2 matrix legs. Modern standard / rubocop transitively pull in
# erb >= 6, which requires Ruby >= 3.2; the gem itself is fine on >= 2.7.
group :lint do
  gem "standard", "~> 1.3"
end

# bin/console needs irb, which is no longer a default gem on Ruby >= 4.0.
# Grouped (not default) so CI's test matrix can skip it: irb pulls rdoc,
# which pulls erb >= 6 — uninstallable on the pre-3.2 legs.
group :console do
  gem "irb"
end
