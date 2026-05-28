require "rails_helper"

RSpec.describe Matchmaking::RateLimitedChat, type: :service do
  # Never really sleep in specs.
  before { allow(described_class).to receive(:pause) }

  def too_many_requests(headers: nil)
    response = headers ? { status: 429, headers: headers } : nil
    Faraday::TooManyRequestsError.new("rate limited", response)
  end

  describe ".with_retry" do
    it "returns the block's value when it succeeds" do
      expect(described_class.with_retry { 42 }).to eq(42)
    end

    it "does not pause when the first attempt succeeds" do
      described_class.with_retry { :ok }
      expect(described_class).not_to have_received(:pause)
    end

    it "retries on a 429 and returns the eventual success" do
      calls = 0
      result = described_class.with_retry do
        calls += 1
        raise too_many_requests if calls < 3
        :done
      end
      expect(result).to eq(:done)
      expect(calls).to eq(3)
      expect(described_class).to have_received(:pause).twice
    end

    it "re-raises after exhausting attempts" do
      expect { described_class.with_retry { raise too_many_requests } }
        .to raise_error(Faraday::TooManyRequestsError)
      expect(described_class).to have_received(:pause).exactly(described_class::MAX_ATTEMPTS - 1).times
    end

    it "does not retry non-429 errors" do
      calls = 0
      expect do
        described_class.with_retry do
          calls += 1
          raise StandardError, "boom"
        end
      end.to raise_error(StandardError, "boom")
      expect(calls).to eq(1)
    end

    it "honors a Retry-After header for the wait length" do
      calls = 0
      described_class.with_retry do
        calls += 1
        raise too_many_requests(headers: { "retry-after" => "7" }) if calls < 2
        :ok
      end
      expect(described_class).to have_received(:pause).with(7)
    end
  end

  describe ".retry_after" do
    it "returns nil when there is no response" do
      expect(described_class.retry_after(too_many_requests)).to be_nil
    end

    it "clamps an oversized Retry-After to the max" do
      error = too_many_requests(headers: { "retry-after" => "9999" })
      expect(described_class.retry_after(error)).to eq(described_class::MAX_DELAY)
    end
  end
end
