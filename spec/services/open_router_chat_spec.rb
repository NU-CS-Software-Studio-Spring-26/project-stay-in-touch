require "rails_helper"

RSpec.describe OpenRouterChat, type: :service do
  # Never really sleep in specs.
  before { allow(described_class).to receive(:pause) }

  def too_many_requests(headers: nil)
    response = headers ? { status: 429, headers: headers } : nil
    Faraday::TooManyRequestsError.new("rate limited", response)
  end

  def payment_required
    Faraday::ClientError.new("payment required", { status: 402 })
  end

  describe ".completion" do
    let(:client_double) { instance_double(OpenAI::Client) }
    let(:response)      { { "choices" => [{ "message" => { "content" => "hi" } }] } }

    before { allow(OpenAI::Client).to receive(:new).and_return(client_double) }

    it "uses the primary (paid) model on the happy path" do
      expect(client_double).to receive(:chat) do |args|
        expect(args[:parameters][:model]).to eq(described_class::PRIMARY_MODEL)
        response
      end
      result = described_class.completion(messages: [{ role: "user", content: "x" }], max_tokens: 10)
      expect(result).to eq(response)
    end

    it "falls back to the free model when the account is out of credit (402)" do
      models = []
      allow(client_double).to receive(:chat) do |args|
        models << args[:parameters][:model]
        raise payment_required if models.size == 1

        response
      end

      result = described_class.completion(messages: [{ role: "user", content: "x" }], max_tokens: 10)
      expect(result).to eq(response)
      expect(models).to eq([ described_class::PRIMARY_MODEL, described_class::FALLBACK_MODEL ])
    end

    it "does not fall back on non-402 errors" do
      allow(client_double).to receive(:chat).and_raise(Faraday::ServerError.new("boom", { status: 500 }))
      expect do
        described_class.completion(messages: [{ role: "user", content: "x" }], max_tokens: 10)
      end.to raise_error(Faraday::ServerError)
    end
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

  describe ".out_of_credit?" do
    it "is true for a 402 response" do
      expect(described_class.out_of_credit?(payment_required)).to be(true)
    end

    it "is false for a 429 response" do
      expect(described_class.out_of_credit?(too_many_requests(headers: {}))).to be(false)
    end

    it "is false when there is no response" do
      expect(described_class.out_of_credit?(too_many_requests)).to be(false)
    end
  end
end
