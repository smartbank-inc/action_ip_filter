# frozen_string_literal: true

require "active_support/concern"

module ActionIpFilter
  module IpFilterable
    extend ActiveSupport::Concern

    included do
      class_attribute :action_ip_restrictions, default: {}
    end

    # @rbs!
    #   type restriction_options = { allowed_ips: Array[String] | ^() -> Array[String], on_denied: (^() -> void)? }
    #   def action_ip_restrictions: () -> Hash[Symbol, untyped]
    #   def action_ip_restrictions=: (Hash[Symbol, untyped]) -> void

    # @rbs!
    #   def request: () -> ActionDispatch::Request
    #   def action_name: () -> String
    #   def instance_exec: (*untyped) { () -> void } -> void
    #   def before_action: (*untyped, **untyped) -> void

    class_methods do
      # @rbs *actions: Symbol
      # @rbs allowed_ips: Array[String] | ^() -> Array[String]
      # @rbs on_denied: (^() -> void)?
      # @rbs return: void
      def filter_ip(*actions, allowed_ips:, on_denied: nil)
        actions.flatten.each do |action|
          self.action_ip_restrictions = action_ip_restrictions.merge(action.to_sym => {allowed_ips:, on_denied:})
          before_action -> { check_ip_restriction(action) }, only: action
        end
      end
    end

    private

    # @rbs action: Symbol
    # @rbs return: void
    def check_ip_restriction(action)
      verify_ip_access(action_ip_restrictions[action.to_sym])
    end

    # @rbs return: void
    def check_ip_restriction_for_all
      verify_ip_access(action_ip_restrictions[:"all-marker"])
    end

    # @rbs restriction: restriction_options?
    # @rbs return: void
    def verify_ip_access(restriction)
      return if restriction.nil? || ActionIpFilter.test_mode?

      client_ip = instance_exec(&ActionIpFilter.configuration.ip_resolver) #: String?
      allowed_ips = resolve_allowed_ips(restriction[:allowed_ips])

      unless IpMatcher.allowed?(client_ip, allowed_ips)
        log_ip_denial(client_ip)
        on_denied = restriction[:on_denied] || ActionIpFilter.configuration.on_denied
        instance_exec(&on_denied)
      end
    end

    # @rbs allowed_ips: Array[String] | ^() -> Array[String]
    # @rbs return: Array[String]
    def resolve_allowed_ips(allowed_ips)
      case allowed_ips
      when Proc
        instance_exec(&allowed_ips) #: Array[String]
      else
        Array(allowed_ips)
      end
    end

    # @rbs client_ip: String?
    # @rbs return: void
    def log_ip_denial(client_ip)
      return unless ActionIpFilter.configuration.log_denials

      logger = ActionIpFilter.configuration.logger
      return if logger.nil?

      logger.warn do
        "[ActionIpFilter] Access denied for IP: #{client_ip} on #{self.class.name}##{action_name}"
      end
    end
  end
end
