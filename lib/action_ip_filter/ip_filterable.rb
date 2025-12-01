# frozen_string_literal: true

require "active_support/concern"

module ActionIpFilter
  module IpFilterable
    extend ActiveSupport::Concern

    # @rbs!
    #   def instance_exec: [T] () { () -> T } -> T
    #                    | (Logger, String?) { (Logger, String?) -> void } -> void
    #   def before_action: (*untyped, **untyped) -> void

    class_methods do
      # @rbs allowed_ips: String | Array[String] | ^() -> Array[String]
      # @rbs on_denied: (^() -> void)?
      # @rbs only: Array[Symbol]?
      # @rbs except: Array[Symbol]?
      # @rbs return: void
      def filter_ip(*allowed_ips, on_denied: nil, only: nil, except: nil)
        before_action -> { verify_ip_access(allowed_ips:, on_denied:) }, only:, except:
      end
    end

    private

    # @rbs allowed_ips: Array[String | Array[String] | ^() -> Array[String]]
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
        end.flatten

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

      log_denial_message = ActionIpFilter.configuration.log_denial_message
      return if log_denial_message.nil?

      instance_exec(logger, client_ip, &log_denial_message)
    end
  end
end
