# frozen_string_literal: true

RSpec.describe ActionIpFilter::Configuration do
  describe "#initialize" do
    subject(:config) { described_class.new }

    it "sets default ip_resolver" do
      expect(config.ip_resolver).to be_a(Proc)
    end

    it "sets on_denied to nil" do
      expect(config.on_denied).to be_a(Proc)
    end

    it "sets logger to nil" do
      expect(config.logger).to be_nil
    end

    it "enables log_denials by default" do
      expect(config.log_denials).to be true
    end
  end

  describe "default ip_resolver" do
    it "calls remote_ip on request" do
      config = described_class.new
      request = double("request", remote_ip: "192.168.1.1")
      context = double("controller", request:)

      result = context.instance_exec(&config.ip_resolver)
      expect(result).to eq("192.168.1.1")
    end
  end
end

RSpec.describe ActionIpFilter do
  describe ".configure" do
    it "yields configuration" do
      expect { |b| described_class.configure(&b) }.to yield_with_args(ActionIpFilter::Configuration)
    end

    it "allows setting custom ip_resolver" do
      custom_resolver = -> { request.headers["X-Real-IP"] }

      described_class.configure do |config|
        config.ip_resolver = custom_resolver
      end

      expect(described_class.configuration.ip_resolver).to eq(custom_resolver)
    end

    it "allows setting custom on_denied handler" do
      custom_handler = -> { head :forbidden }

      described_class.configure do |config|
        config.on_denied = custom_handler
      end

      expect(described_class.configuration.on_denied).to eq(custom_handler)
    end
  end

  describe ".reset_configuration!" do
    it "resets to default configuration" do
      described_class.configure do |config|
        config.log_denials = false
      end

      described_class.reset_configuration!

      expect(described_class.configuration.log_denials).to be true
    end
  end

  describe ".test_mode" do
    it "defaults to false" do
      expect(described_class.test_mode?).to be false
    end

    it "can be set to true" do
      described_class.test_mode = true
      expect(described_class.test_mode?).to be true
    end
  end
end
