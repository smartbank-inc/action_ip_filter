# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActionIpFilter::IpFilterable, type: :controller do
  describe ".filter_ip" do
    context ":only" do
      controller(ActionController::Base) do
        include ActionIpFilter::IpFilterable

        filter_ip "192.168.1.0/24", "10.0.0.1", %w[10.0.0.2 10.0.0.3], -> { %w[10.0.0.4 10.0.0.5/32] }, only: [:index]
        filter_ip "10.0.0.0/8", only: [:show, :edit]
        filter_ip -> { ["10.0.0.0/8"] }, only: [:custom_denied], on_denied: -> { head :unauthorized }

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

      context "allowed IP address" do
        %w[192.168.1.100 10.0.0.1 10.0.0.2 10.0.0.3, 10.0.0.4, 10.0.0.5].each do |remote_addr|
          context do
            before do
              request.env["REMOTE_ADDR"] = remote_addr
            end

            it "allows access" do
              get :index
              expect(response).to have_http_status(:ok)
              expect(response.parsed_body).to eq("status" => "ok")
            end
          end
        end
      end

      context "denied IP address" do
        before do
          request.env["REMOTE_ADDR"] = "10.0.0.100"
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

          filter_ip -> { ["192.168.1.0/24"] }, only: [:dynamic_ips]

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

          filter_ip -> { allowed_ip_list }, only: [:index]

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

    context ":except" do
      controller(ActionController::Base) do
        include ActionIpFilter::IpFilterable

        filter_ip "192.168.1.0/24", except: [:action_one]

        def action_one
          render json: {status: "ok"}
        end

        def action_two
          render json: {status: "ok"}
        end
      end

      before do
        routes.draw do
          get "action_one" => "anonymous#action_one"
          get "action_two" => "anonymous#action_two"
        end
      end

      context "allowed IP address" do
        before do
          request.env["REMOTE_ADDR"] = "192.168.2.100" # out of IP range
        end

        it "allows access" do
          get :action_one
          expect(response).to have_http_status(:ok)
          get :action_two
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context "all actions (no scope modifiers)" do
      controller(ActionController::Base) do
        include ActionIpFilter::IpFilterable

        filter_ip "192.168.1.0/24"

        def action_one
          render json: {status: "ok"}
        end

        def action_two
          render json: {status: "ok"}
        end
      end

      before do
        routes.draw do
          get "action_one" => "anonymous#action_one"
          get "action_two" => "anonymous#action_two"
        end
      end

      context "allowed IP address" do
        before do
          request.env["REMOTE_ADDR"] = "192.168.1.100"
        end

        it "allows access" do
          get :action_one
          expect(response).to have_http_status(:ok)
          get :action_two
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context "with both :only and :except specified" do
      controller(ActionController::Base) do
        include ActionIpFilter::IpFilterable

        filter_ip "192.168.1.0/24", only: [:action_one, :action_two], except: [:action_two, :action_three]

        def action_one
          render json: {status: "ok"}
        end

        def action_two
          render json: {status: "ok"}
        end

        def action_three
          render json: {status: "ok"}
        end
      end

      before do
        routes.draw do
          get "action_one" => "anonymous#action_one"
          get "action_two" => "anonymous#action_two"
          get "action_three" => "anonymous#action_three"
        end
      end

      context "allowed IP address" do
        before do
          request.env["REMOTE_ADDR"] = "192.168.2.100" # out of IP range
        end

        it "allows access" do
          get :action_one
          expect(response).to have_http_status(:forbidden)
          get :action_two
          expect(response).to have_http_status(:ok)
          get :action_three
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  describe "test_mode" do
    controller(ActionController::Base) do
      include ActionIpFilter::IpFilterable

      filter_ip "10.0.0.0/8", only: [:index]

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

      filter_ip "10.0.0.0/8", only: [:index]

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

      filter_ip "10.0.0.0/8", only: [:index]

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

      filter_ip "10.0.0.0/8", only: [:index]

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

      filter_ip "10.0.0.0/8", only: [:admin]
      filter_ip "192.168.1.0/24", only: [:api]

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

        filter_ip only: [:index]

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

        filter_ip "192.168.1.0/24", only: [:index]

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
