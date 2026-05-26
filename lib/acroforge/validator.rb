# frozen_string_literal: true

require "date"
require "uri"

module AcroForge
  class ValidationError < StandardError; end

  module Validator
    def self.valid?(value, type, options = [])
      return true if value.nil? || value.to_s.empty?

      case type
      when :money
        value.to_s.gsub(/[$,]/, "").match?(/^\d+(\.\d+)?$/)
      when :date
        begin
          Date.parse(value.to_s)
          true
        rescue ArgumentError, TypeError
          false
        end
      when :email
        value.to_s.match?(URI::MailTo::EMAIL_REGEXP)
      when :number
        value.to_s.gsub(/[\s-]/, "").match?(/^\d+$/)
      when :boolean
        ["true", "false", "yes", "no", "1", "0", "on", "off"].include?(value.to_s.downcase)
      when :select
        val_str = value.to_s.downcase
        options.any? { |o| o.to_s.downcase == val_str }
      else
        true
      end
    end
  end
end
