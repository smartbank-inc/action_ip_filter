# frozen_string_literal: true

require "active_support"
require "active_support/core_ext/object/blank"

require_relative "action_ip_filter/version"
require_relative "action_ip_filter/configuration"
require_relative "action_ip_filter/ip_matcher"
require_relative "action_ip_filter/ip_filterable"
require_relative "action_ip_filter/test_helpers"
require_relative "action_ip_filter/railtie" if defined?(Rails::Railtie)

module ActionIpFilter
  # @rbs!
  #   def self.test_mode=: (bool) -> bool

  class << self
    # @rbs @test_mode: bool

    attr_accessor :test_mode #: bool

    # @rbs return: bool
    def test_mode?
      @test_mode == true
    end
  end

  self.test_mode = false
end
