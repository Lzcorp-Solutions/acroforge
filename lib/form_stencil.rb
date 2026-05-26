# frozen_string_literal: true

require_relative "form_stencil/version"
require_relative "form_stencil/constants"

module FormStencil
  class Error < StandardError; end
end

require_relative "form_stencil/all_text_processor"
require_relative "form_stencil/validator"
require_relative "form_stencil/engine"
require_relative "form_stencil/schema"
