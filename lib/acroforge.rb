# frozen_string_literal: true

require_relative "acroforge/version"
require_relative "acroforge/constants"

module AcroForge
  class Error < StandardError; end
end

require_relative "acroforge/all_text_processor"
require_relative "acroforge/labels"
require_relative "acroforge/validator"
require_relative "acroforge/engine"
require_relative "acroforge/schema"
require_relative "acroforge/relabeler"
require_relative "acroforge/annotator"
require_relative "acroforge/preparer"
require_relative "acroforge/cli"
