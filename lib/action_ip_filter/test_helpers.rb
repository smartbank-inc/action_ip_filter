# frozen_string_literal: true

module ActionIpFilter
  module TestHelpers
    # @rbs [T] () { () -> T } -> T
    def without_ip_filter(&block)
      original_mode = ActionIpFilter.test_mode?
      ActionIpFilter.test_mode = true
      block.call
    ensure
      ActionIpFilter.test_mode = original_mode
    end

    # @rbs [T] () { () -> T } -> T
    def with_ip_filter(&block)
      original_mode = ActionIpFilter.test_mode?
      ActionIpFilter.test_mode = false
      block.call
    ensure
      ActionIpFilter.test_mode = original_mode
    end

    # @rbs return: void
    def enable_ip_filter_test_mode!
      ActionIpFilter.test_mode = true
    end

    # @rbs return: void
    def disable_ip_filter_test_mode!
      ActionIpFilter.test_mode = false
    end
  end
end
