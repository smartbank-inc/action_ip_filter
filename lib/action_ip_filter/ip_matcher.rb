# frozen_string_literal: true

require "ipaddr"

module ActionIpFilter
  module IpMatcher
    class << self
      # @rbs client_ip: String?
      # @rbs allowed_ips: Array[String]
      # @rbs return: bool
      def allowed?(client_ip, allowed_ips)
        return false if client_ip.nil? || client_ip.empty? || allowed_ips.empty?

        client_addr = parse_ip(client_ip)
        return false unless client_addr

        allowed_ips.any? do |allowed_ip|
          match?(client_addr, allowed_ip)
        end
      end

      private

      # @rbs ip_string: String
      # @rbs return: IPAddr?
      def parse_ip(ip_string)
        IPAddr.new(ip_string)
      rescue IPAddr::InvalidAddressError
        nil
      end

      # @rbs client_addr: IPAddr
      # @rbs allowed_ip: String
      # @rbs return: bool
      def match?(client_addr, allowed_ip)
        if allowed_ip.include?("/")
          range = IPAddr.new(allowed_ip)
          range.include?(client_addr)
        else
          allowed_addr = IPAddr.new(allowed_ip)
          client_addr == allowed_addr
        end
      rescue IPAddr::InvalidAddressError
        false
      end
    end
  end
end
