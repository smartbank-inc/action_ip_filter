# frozen_string_literal: true

module ActionIpFilter
  class Configuration
    # @rbs @ip_resolver: ^() -> String?
    # @rbs @on_denied: ^() -> void
    # @rbs @logger: Logger?
    # @rbs @log_denials: bool
    # @rbs @log_denial_message: ^(Logger, String?) -> void

    # @rbs!
    #   interface _Request
    #     def remote_ip: () -> String
    #   end
    #
    #   def action_name: () -> String
    #   def controller_name: () -> String
    #   def head: (Symbol) -> void
    #   def request: () -> _Request

    attr_accessor :ip_resolver #: ^() -> String?
    attr_accessor :on_denied #: ^() -> void
    attr_accessor :logger #: Logger?
    attr_accessor :log_denials #: bool
    attr_accessor :log_denial_message #: ^(Logger, String?) -> void

    # @rbs return: void
    def initialize
      @ip_resolver = -> { request.remote_ip }
      @on_denied = -> { head :forbidden }
      @logger = nil
      @log_denials = true
      @log_denial_message = ->(logger, client_ip) {
        logger.warn("[ActionIpFilter] Access denied for IP: #{client_ip} on #{self.class.name}##{action_name}")
      }
    end
  end

  class << self
    # @rbs @configuration: Configuration?

    # @rbs return: Configuration
    def configuration
      @configuration ||= Configuration.new
    end

    # @rbs () { (Configuration) -> void } -> void
    def configure
      yield(configuration)
    end

    # @rbs return: void
    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
