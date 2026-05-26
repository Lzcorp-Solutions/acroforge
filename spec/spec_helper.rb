# frozen_string_literal: true

require "form_stencil"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

def silence_stdout
  orig = $stdout
  $stdout = File.open(File::NULL, "w")
  yield
ensure
  $stdout.close if $stdout && !$stdout.closed?
  $stdout = orig
end
