# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActionIpFilter::IpFilterable, type: :controller do
  describe ".filter_ip" do
    controller(ActionController::Base) do
      include ActionIpFilter::IpFilterable

      filter_ip :index, allowed_ips: ["192.168.1.0/24"]
      filter_ip :show, :edit, allowed_ips: ["10.0.0.0/8"]
      filter_ip :custom_denied, allowed_ips: -> { ["10.0.0.0/8"] }, on_denied: -> { head :unauthorized }

      def index
        render json: {status: "ok"}
      end

      def show
        render json: {status: "ok"}
      end

      def edit
        render json: {status: "ok"}
      end

      def custom_denied
        render json: {status: "ok"}
      end

      def unrestricted
        render json: {status: "ok"}
      end

      def dynamic_ips
        render json: {status: "ok"}
      end

      def allowed_ip_list
        ["192.168.1.0/24"]
      end
    end

    before do
      routes.draw do
        get "index" => "anonymous#index"
        get "show" => "anonymous#show"
        get "edit" => "anonymous#edit"
        get "custom_denied" => "anonymous#custom_denied"
        get "unrestricted" => "anonymous#unrestricted"
        get "dynamic_ips" => "anonymous#dynamic_ips"
      end
    end

    it "registers before_action for specified actions" do
      expect(controller.class.action_ip_restrictions).to include(:index, :show, :edit)
    end

    it "stores allowed_ips and on_denied in action_ip_restrictions" do
      restriction = controller.class.action_ip_restrictions[:custom_denied]
      expect(restriction[:allowed_ips]).to be_a(Proc)
      expect(restriction[:on_denied]).to be_a(Proc)
    end

    context "allowed IP address" do
      before do
        request.env["REMOTE_ADDR"] = "192.168.1.100"
      end

      it "allows access" do
        get :index
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq("status" => "ok")
      end
    end

    context "denied IP address" do
      before do
        request.env["REMOTE_ADDR"] = "10.0.0.1"
      end

      it "returns :forbidden" do
        get :index
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "custom on_denied callback" do
      before do
        request.env["REMOTE_ADDR"] = "192.168.2.1"
      end

      it "uses custom on_denied callback" do
        get :custom_denied
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "Proc for allowed_ips" do
      controller(ActionController::Base) do
        include ActionIpFilter::IpFilterable

        filter_ip :dynamic_ips, allowed_ips: -> { ["192.168.1.0/24"] }

        def dynamic_ips
          render json: {status: "ok"}
        end
      end

      before do
        routes.draw do
          get "dynamic_ips" => "anonymous#dynamic_ips"
        end
        request.env["REMOTE_ADDR"] = "192.168.1.100"
      end

      it "accepts and evaluates Proc" do
        get :dynamic_ips
        expect(response).to have_http_status(:ok)
      end
    end

    context "Proc evaluated in controller context" do
      controller(ActionController::Base) do
        include ActionIpFilter::IpFilterable

        filter_ip :index, allowed_ips: -> { allowed_ip_list }

        def index
          render json: {status: "ok"}
        end

        def allowed_ip_list
          ["192.168.1.0/24"]
        end
      end

      before do
        routes.draw do
          get "index" => "anonymous#index"
        end
        request.env["REMOTE_ADDR"] = "192.168.1.100"
      end

      it "evaluates Proc in controller context" do
        get :index
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "test_mode" do
    controller(ActionController::Base) do
      include ActionIpFilter::IpFilterable

      filter_ip :index, allowed_ips: ["10.0.0.0/8"]

      def index
        render json: {status: "ok"}
      end
    end

    before do
      routes.draw do
        get "index" => "anonymous#index"
      end
      request.env["REMOTE_ADDR"] = "192.168.1.100"
    end

    it "skips IP verification when test_mode is enabled" do
      ActionIpFilter.test_mode = true
      get :index
      expect(response).to have_http_status(:ok)
    end
  end

  describe "custom ip_resolver" do
    controller(ActionController::Base) do
      include ActionIpFilter::IpFilterable

      filter_ip :index, allowed_ips: ["10.0.0.0/8"]

      def index
        render json: {status: "ok"}
      end
    end

    before do
      routes.draw do
        get "index" => "anonymous#index"
      end
      ActionIpFilter.configure do |config|
        config.ip_resolver = -> { request.env["HTTP_X_REAL_IP"] }
      end
      request.env["HTTP_X_REAL_IP"] = "10.0.0.1"
    end

    it "uses configured ip_resolver" do
      get :index
      expect(response).to have_http_status(:ok)
    end
  end

  describe "global on_denied" do
    controller(ActionController::Base) do
      include ActionIpFilter::IpFilterable

      filter_ip :index, allowed_ips: ["10.0.0.0/8"]

      def index
        render json: {status: "ok"}
      end
    end

    before do
      routes.draw do
        get "index" => "anonymous#index"
      end
      ActionIpFilter.configure do |config|
        config.on_denied = -> { head :service_unavailable }
      end
      request.env["REMOTE_ADDR"] = "192.168.1.100"
    end

    it "uses global on_denied when action-specific one is not provided" do
      get :index
      expect(response).to have_http_status(:service_unavailable)
    end
  end

  describe "logging" do
    let(:logger) { instance_double("Logger") }

    controller(ActionController::Base) do
      include ActionIpFilter::IpFilterable

      filter_ip :index, allowed_ips: ["10.0.0.0/8"]

      def index
        render json: {status: "ok"}
      end
    end

    before do
      routes.draw do
        get "index" => "anonymous#index"
      end
      request.env["REMOTE_ADDR"] = "192.168.1.100"
    end

    context "log_denials is true" do
      before do
        ActionIpFilter.configure do |config|
          config.logger = logger
          config.log_denials = true
        end
      end

      it "logs denial with correct message" do
        expect(logger).to receive(:warn) do |&block|
          message = block.call
          expect(message).to eq("[ActionIpFilter] Access denied for IP: 192.168.1.100 on AnonymousController#index")
        end
        get :index
      end
    end

    context "log_denials is false" do
      before do
        ActionIpFilter.configure do |config|
          config.logger = logger
          config.log_denials = false
        end
      end

      it "does not log" do
        expect(logger).not_to receive(:warn)
        get :index
      end
    end

    context "logger is nil" do
      before do
        ActionIpFilter.configure do |config|
          config.logger = nil
          config.log_denials = true
        end
      end

      it "does not raise error" do
        expect { get :index }.not_to raise_error
      end
    end
  end

  describe "multiple restrictions" do
    controller(ActionController::Base) do
      include ActionIpFilter::IpFilterable

      filter_ip :admin, allowed_ips: ["10.0.0.0/8"]
      filter_ip :api, allowed_ips: ["192.168.1.0/24"]

      def admin
        render json: {status: "ok"}
      end

      def api
        render json: {status: "ok"}
      end
    end

    before do
      routes.draw do
        get "admin" => "anonymous#admin"
        get "api" => "anonymous#api"
      end
      request.env["REMOTE_ADDR"] = "192.168.1.100"
    end

    it "allows different IP lists for different actions" do
      get :admin
      expect(response).to have_http_status(:forbidden)

      get :api
      expect(response).to have_http_status(:ok)
    end
  end

  describe "edge cases" do
    context "empty allowed_ips array" do
      controller(ActionController::Base) do
        include ActionIpFilter::IpFilterable

        filter_ip :index, allowed_ips: []

        def index
          render json: {status: "ok"}
        end
      end

      before do
        routes.draw do
          get "index" => "anonymous#index"
        end
        request.env["REMOTE_ADDR"] = "192.168.1.100"
      end

      it "denies all access" do
        get :index
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "nil client IP" do
      controller(ActionController::Base) do
        include ActionIpFilter::IpFilterable

        filter_ip :index, allowed_ips: ["192.168.1.0/24"]

        def index
          render json: {status: "ok"}
        end
      end

      before do
        routes.draw do
          get "index" => "anonymous#index"
        end
        ActionIpFilter.configure do |config|
          config.ip_resolver = -> {}
        end
      end

      it "denies access" do
        get :index
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
