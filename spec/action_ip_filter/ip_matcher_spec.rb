# frozen_string_literal: true

RSpec.describe ActionIpFilter::IpMatcher do
  describe ".allowed?" do
    context "with single IP addresses" do
      it "returns true when client IP matches allowed IP" do
        expect(described_class.allowed?("192.168.1.1", ["192.168.1.1"])).to be true
      end

      it "returns false when client IP does not match" do
        expect(described_class.allowed?("192.168.1.2", ["192.168.1.1"])).to be false
      end

      it "returns true when client IP matches any of the allowed IPs" do
        expect(described_class.allowed?("10.0.0.5", ["192.168.1.1", "10.0.0.5"])).to be true
      end
    end

    context "with CIDR ranges" do
      it "returns true when client IP is within CIDR range" do
        expect(described_class.allowed?("192.168.1.50", ["192.168.1.0/24"])).to be true
      end

      it "returns false when client IP is outside CIDR range" do
        expect(described_class.allowed?("192.168.2.1", ["192.168.1.0/24"])).to be false
      end

      it "handles /32 (single host) CIDR" do
        expect(described_class.allowed?("10.0.0.1", ["10.0.0.1/32"])).to be true
        expect(described_class.allowed?("10.0.0.2", ["10.0.0.1/32"])).to be false
      end

      it "handles /16 CIDR range" do
        expect(described_class.allowed?("172.16.255.255", ["172.16.0.0/16"])).to be true
        expect(described_class.allowed?("172.17.0.1", ["172.16.0.0/16"])).to be false
      end
    end

    context "with IPv6 addresses" do
      it "returns true for matching IPv6 address" do
        expect(described_class.allowed?("::1", ["::1"])).to be true
      end

      it "returns true for IPv6 within CIDR range" do
        expect(described_class.allowed?("2001:db8::1", ["2001:db8::/32"])).to be true
      end

      it "returns false for IPv6 outside CIDR range" do
        expect(described_class.allowed?("2001:db9::1", ["2001:db8::/32"])).to be false
      end
    end

    context "with mixed single IPs and CIDR ranges" do
      let(:allowed_ips) { ["10.0.0.1", "192.168.1.0/24", "172.16.0.0/16"] }

      it "returns true for exact match" do
        expect(described_class.allowed?("10.0.0.1", allowed_ips)).to be true
      end

      it "returns true for match within first CIDR" do
        expect(described_class.allowed?("192.168.1.100", allowed_ips)).to be true
      end

      it "returns true for match within second CIDR" do
        expect(described_class.allowed?("172.16.50.50", allowed_ips)).to be true
      end

      it "returns false for non-matching IP" do
        expect(described_class.allowed?("8.8.8.8", allowed_ips)).to be false
      end
    end

    context "with edge cases" do
      it "returns false for blank client IP" do
        expect(described_class.allowed?("", ["192.168.1.1"])).to be false
        expect(described_class.allowed?(nil, ["192.168.1.1"])).to be false
      end

      it "returns false for empty allowed IPs" do
        expect(described_class.allowed?("192.168.1.1", [])).to be false
      end

      it "returns false for invalid client IP format" do
        expect(described_class.allowed?("invalid-ip", ["192.168.1.1"])).to be false
      end

      it "returns false for invalid allowed IP format" do
        expect(described_class.allowed?("192.168.1.1", ["invalid-ip"])).to be false
      end

      it "continues checking after invalid allowed IP" do
        expect(described_class.allowed?("192.168.1.1", ["invalid-ip", "192.168.1.1"])).to be true
      end
    end
  end
end
