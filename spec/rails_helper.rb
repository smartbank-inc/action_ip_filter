# frozen_string_literal: true

require "spec_helper"

# Minimal Rails application for testing
require "rails"
require "action_controller/railtie"

# Dummy Rails application
class TestApp < Rails::Application
  config.eager_load = false
  config.secret_key_base = "test_secret_key_base"
  config.hosts.clear
end

TestApp.initialize!

# Configure rspec-rails
require "rspec/rails"

RSpec.configure do |config|
  config.infer_spec_type_from_file_location!
end
