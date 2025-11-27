# frozen_string_literal: true

require "rails/railtie"

module ActionIpFilter
  class Railtie < Rails::Railtie
    initializer "action_ip_filter.configure" do
      ActionIpFilter.configuration.logger ||= Rails.logger
    end
  end
end
