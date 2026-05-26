# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "form_stencil"

RSpec.describe FormStencil::Engine do
  let(:semantic_fixture) { File.expand_path("../fixtures/semantic_named.pdf", __dir__) }

  around do |example|
    Dir.mktmpdir do |tmp|
      @tmp = tmp
      example.run
    end
  end

  describe "#compile! with no schema" do
    it "returns a result hash with the documented keys" do
      engine = described_class.new(semantic_fixture, normalized_dir: @tmp)
      result = silence_stdout { engine.compile! }

      expect(result.keys).to match_array(%i[mapped unmapped select_options new_fields_detected])
      expect(result[:mapped]).to be_a(Hash)
      expect(result[:mapped]).not_to be_empty
    end
  end
end
