# frozen_string_literal: true

module ActionIpFilter
  class Configuration
    # @rbs @ip_resolver: ^() -> String?
    # @rbs @on_denied: ^() -> void
    # @rbs @logger: Logger?
    # @rbs @log_denials: bool

    attr_accessor :ip_resolver #: ^() -> String?
    attr_accessor :on_denied #: ^() -> void
    attr_accessor :logger #: Logger?
    attr_accessor :log_denials #: bool

    # @rbs return: void
    def initialize
      @ip_resolver = -> { request.remote_ip } # steep:ignore NoMethod
      @on_denied = -> { head :forbidden } # steep:ignore NoMethod
      @logger = nil
      @log_denials = true
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
