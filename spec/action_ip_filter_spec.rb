# frozen_string_literal: true

RSpec.describe ActionIpFilter do
  it "has a version number" do
    expect(ActionIpFilter::VERSION).not_to be_nil
  end

  describe ".test_mode" do
    it "can be toggled" do
      described_class.test_mode = true
      expect(described_class.test_mode?).to be true

      described_class.test_mode = false
      expect(described_class.test_mode?).to be false
    end
  end
end
