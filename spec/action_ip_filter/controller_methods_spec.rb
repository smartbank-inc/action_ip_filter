# frozen_string_literal: true

require "ostruct"

class FakeController
  extend ActiveSupport::Concern

  class << self
    def class_attribute(name, default:)
      class_eval do
        instance_variable_set(:"@#{name}", default.dup)
        define_singleton_method(name) { instance_variable_get(:"@#{name}") }
        define_singleton_method(:"#{name}=") { |val| instance_variable_set(:"@#{name}", val) }
        define_method(name) { self.class.send(name) }
      end
    end

    def before_action(callback, **options)
      @before_actions ||= []
      @before_actions << {callback: callback, options: options}
    end

    def before_actions
      @before_actions ||= []
    end
  end

  attr_accessor :request, :rendered_status, :action_name

  def head(status)
    @rendered_status = status
  end

  def initialize
    @action_name = "index"
  end

  def run_before_actions(action)
    self.class.before_actions.each do |ba|
      only = ba[:options][:only]
      except = ba[:options][:except]
      next if only && !Array(only).include?(action)
      next if except && Array(except).include?(action)

      case ba[:callback]
      when Symbol
        send(ba[:callback])
      when Proc
        instance_exec(&ba[:callback])
      end
    end
  end
end

RSpec.describe ActionIpFilter::ControllerMethods do
  # Build a fresh controller class for each test to avoid state leakage
  def build_controller_class
    klass = Class.new(FakeController)
    klass.include(ActionIpFilter::ControllerMethods)
    klass
  end

  let(:controller_class) { build_controller_class }

  let(:mock_request) do
    OpenStruct.new(remote_ip: "192.168.1.100")
  end

  let(:controller) do
    c = controller_class.new
    c.request = mock_request
    c
  end

  before do
    ActionIpFilter.reset_configuration!
    ActionIpFilter.test_mode = false
  end

  describe ".restrict_ip" do
    it "registers before_action for specified actions" do
      controller_class.restrict_ip(:show, :edit, allowed_ips: ["192.168.1.0/24"])

      expect(controller_class.action_ip_restrictions).to include(:show, :edit)
      expect(controller_class.before_actions.size).to eq(2)
    end

    it "stores allowed_ips and on_denied in action_ip_restrictions" do
      on_denied_proc = -> { head :unauthorized }
      controller_class.restrict_ip(:index, allowed_ips: ["10.0.0.0/8"], on_denied: on_denied_proc)

      restriction = controller_class.action_ip_restrictions[:index]
      expect(restriction[:allowed_ips]).to eq(["10.0.0.0/8"])
      expect(restriction[:on_denied]).to eq(on_denied_proc)
    end

    it "allows access from allowed IP" do
      controller_class.restrict_ip(:index, allowed_ips: ["192.168.1.0/24"])
      controller.action_name = "index"
      controller.run_before_actions(:index)

      expect(controller.rendered_status).to be_nil
    end

    it "denies access from non-allowed IP" do
      controller_class.restrict_ip(:index, allowed_ips: ["10.0.0.0/8"])
      controller.action_name = "index"
      controller.run_before_actions(:index)

      expect(controller.rendered_status).to eq(:forbidden)
    end

    it "uses custom on_denied callback when provided" do
      controller_class.restrict_ip(:index, allowed_ips: ["10.0.0.0/8"], on_denied: -> { head :unauthorized })
      controller.action_name = "index"
      controller.run_before_actions(:index)

      expect(controller.rendered_status).to eq(:unauthorized)
    end

    it "accepts a Proc for allowed_ips" do
      controller_class.restrict_ip(:index, allowed_ips: -> { ["192.168.1.0/24"] })
      controller.action_name = "index"
      controller.run_before_actions(:index)

      expect(controller.rendered_status).to be_nil
    end

    it "evaluates Proc in controller context" do
      controller_class.class_eval do
        def allowed_ip_list
          ["192.168.1.0/24"]
        end
      end
      controller_class.restrict_ip(:index, allowed_ips: -> { allowed_ip_list })
      controller.action_name = "index"
      controller.run_before_actions(:index)

      expect(controller.rendered_status).to be_nil
    end
  end

  describe ".restrict_ip_for_all" do
    it "registers before_action for all actions" do
      controller_class.restrict_ip_for_all(allowed_ips: ["192.168.1.0/24"])

      expect(controller_class.action_ip_restrictions).to include(:"all-marker")
      expect(controller_class.before_actions.size).to eq(1)
    end

    it "allows access from allowed IP" do
      controller_class.restrict_ip_for_all(allowed_ips: ["192.168.1.0/24"])
      controller.run_before_actions(:any_action)

      expect(controller.rendered_status).to be_nil
    end

    it "denies access from non-allowed IP" do
      controller_class.restrict_ip_for_all(allowed_ips: ["10.0.0.0/8"])
      controller.run_before_actions(:any_action)

      expect(controller.rendered_status).to eq(:forbidden)
    end

    it "respects except option" do
      controller_class.restrict_ip_for_all(allowed_ips: ["10.0.0.0/8"], except: [:public_action])

      # Denied for non-excepted action
      controller.run_before_actions(:private_action)
      expect(controller.rendered_status).to eq(:forbidden)

      # Reset and test excepted action
      controller.rendered_status = nil
      controller.run_before_actions(:public_action)
      expect(controller.rendered_status).to be_nil
    end
  end

  describe "test_mode" do
    it "skips IP verification when test_mode is enabled" do
      ActionIpFilter.test_mode = true
      controller_class.restrict_ip(:index, allowed_ips: ["10.0.0.0/8"])
      controller.action_name = "index"
      controller.run_before_actions(:index)

      expect(controller.rendered_status).to be_nil
    end
  end

  describe "custom ip_resolver" do
    it "uses configured ip_resolver" do
      ActionIpFilter.configure do |config|
        config.ip_resolver = ->(request) { request.env["HTTP_X_REAL_IP"] }
      end

      mock_request_with_env = OpenStruct.new(env: {"HTTP_X_REAL_IP" => "10.0.0.1"})
      controller.request = mock_request_with_env

      controller_class.restrict_ip(:index, allowed_ips: ["10.0.0.0/8"])
      controller.action_name = "index"
      controller.run_before_actions(:index)

      expect(controller.rendered_status).to be_nil
    end
  end

  describe "global on_denied" do
    it "uses global on_denied when action-specific one is not provided" do
      ActionIpFilter.configure do |config|
        config.on_denied = -> { head :service_unavailable }
      end

      controller_class.restrict_ip(:index, allowed_ips: ["10.0.0.0/8"])
      controller.action_name = "index"
      controller.run_before_actions(:index)

      expect(controller.rendered_status).to eq(:service_unavailable)
    end
  end

  describe "logging" do
    let(:logger) { instance_double("Logger") }

    before do
      ActionIpFilter.configure do |config|
        config.logger = logger
        config.log_denials = true
      end
    end

    it "logs denial when log_denials is true" do
      expect(logger).to receive(:warn).and_yield

      controller_class.restrict_ip(:index, allowed_ips: ["10.0.0.0/8"])
      controller.action_name = "index"
      controller.run_before_actions(:index)
    end

    it "does not log when log_denials is false" do
      ActionIpFilter.configuration.log_denials = false
      expect(logger).not_to receive(:warn)

      controller_class.restrict_ip(:index, allowed_ips: ["10.0.0.0/8"])
      controller.action_name = "index"
      controller.run_before_actions(:index)
    end

    it "does not log when logger is nil" do
      ActionIpFilter.configuration.logger = nil

      # Should not raise error
      controller_class.restrict_ip(:index, allowed_ips: ["10.0.0.0/8"])
      controller.action_name = "index"
      expect { controller.run_before_actions(:index) }.not_to raise_error
    end
  end

  describe "multiple restrictions" do
    it "allows different IP lists for different actions" do
      controller_class.restrict_ip(:admin, allowed_ips: ["10.0.0.0/8"])
      controller_class.restrict_ip(:api, allowed_ips: ["192.168.1.0/24"])

      # Request from 192.168.1.100
      controller.action_name = "admin"
      controller.run_before_actions(:admin)
      expect(controller.rendered_status).to eq(:forbidden)

      controller.rendered_status = nil
      controller.action_name = "api"
      controller.run_before_actions(:api)
      expect(controller.rendered_status).to be_nil
    end
  end

  describe "edge cases" do
    it "handles empty allowed_ips array" do
      controller_class.restrict_ip(:index, allowed_ips: [])
      controller.action_name = "index"
      controller.run_before_actions(:index)

      expect(controller.rendered_status).to eq(:forbidden)
    end

    it "handles nil client IP" do
      ActionIpFilter.configure do |config|
        config.ip_resolver = ->(_request) {}
      end

      controller_class.restrict_ip(:index, allowed_ips: ["192.168.1.0/24"])
      controller.action_name = "index"
      controller.run_before_actions(:index)

      expect(controller.rendered_status).to eq(:forbidden)
    end
  end
end
