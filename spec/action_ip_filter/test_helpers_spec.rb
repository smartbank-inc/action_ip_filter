# frozen_string_literal: true

RSpec.describe ActionIpFilter::TestHelpers do
  let(:test_class) do
    Class.new do
      include ActionIpFilter::TestHelpers
    end
  end

  let(:instance) { test_class.new }

  describe "#without_ip_filter" do
    it "enables test mode during block execution" do
      ActionIpFilter.test_mode = false

      instance.without_ip_filter do
        expect(ActionIpFilter.test_mode?).to be true
      end
    end

    it "restores original test mode after block" do
      ActionIpFilter.test_mode = false

      instance.without_ip_filter {}

      expect(ActionIpFilter.test_mode?).to be false
    end

    it "restores original test mode even if block raises" do
      ActionIpFilter.test_mode = false

      expect {
        instance.without_ip_filter { raise "error" }
      }.to raise_error("error")

      expect(ActionIpFilter.test_mode?).to be false
    end
  end

  describe "#with_ip_filter" do
    it "disables test mode during block execution" do
      ActionIpFilter.test_mode = true

      instance.with_ip_filter do
        expect(ActionIpFilter.test_mode?).to be false
      end
    end

    it "restores original test mode after block" do
      ActionIpFilter.test_mode = true

      instance.with_ip_filter {}

      expect(ActionIpFilter.test_mode?).to be true
    end
  end

  describe "#enable_ip_filter_test_mode!" do
    it "sets test mode to true" do
      ActionIpFilter.test_mode = false

      instance.enable_ip_filter_test_mode!

      expect(ActionIpFilter.test_mode?).to be true
    end
  end

  describe "#disable_ip_filter_test_mode!" do
    it "sets test mode to false" do
      ActionIpFilter.test_mode = true

      instance.disable_ip_filter_test_mode!

      expect(ActionIpFilter.test_mode?).to be false
    end
  end
end
