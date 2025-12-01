# frozen_string_literal: true

require "active_support/concern"

module ActionIpFilter
  module IpFilterable
    extend ActiveSupport::Concern

    # @rbs!
    #   def action_name: () -> String
    #   def instance_exec: [T] (*untyped) { () -> T } -> T
    #   def before_action: (*untyped, **untyped) -> void

    class_methods do
      # @rbs allowed_ips: String | ^() -> Array[String]
      # @rbs on_denied: (^() -> void)?
      # @rbs only: Array[Symbol]?
      # @rbs except: Array[Symbol]?
      # @rbs return: void
      def filter_ip(*allowed_ips, on_denied: nil, only: nil, except: nil)
        before_action -> { verify_ip_access(allowed_ips:, on_denied:) }, only:, except:
      end
    end

    private

    # @rbs allowed_ips: Array[String | ^() -> Array[String]]
    # @rbs on_denied: (^() -> void)?
    # @rbs return: void
    def verify_ip_access(allowed_ips:, on_denied:)
      return if ActionIpFilter.test_mode?

      client_ip = instance_exec(&ActionIpFilter.configuration.ip_resolver)

      allowed = allowed_ips.any? do |allowed_ip|
        ips = case allowed_ip
        when Proc
          instance_exec(&allowed_ip)
        else
          [allowed_ip]
        end

        IpMatcher.allowed?(client_ip, ips)
      end

      unless allowed
        log_ip_denial(client_ip)
        instance_exec(&on_denied || ActionIpFilter.configuration.on_denied)
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
