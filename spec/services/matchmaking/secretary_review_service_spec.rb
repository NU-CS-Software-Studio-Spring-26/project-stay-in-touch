require "rails_helper"

RSpec.describe Matchmaking::SecretaryReviewService, type: :service do
  let(:recipient) do
    create(:user, :matchmaking_ready, display_name: "Recipient",
           meeting_interests: "Only want investor intros")
  end

  subject(:service) { described_class.new(recipient, "Requester", "Can we meet about my startup?") }

  let(:client_double) { instance_double(OpenAI::Client) }
  before { allow(OpenAI::Client).to receive(:new).and_return(client_double) }

  def response_with(content)
    { "choices" => [{ "message" => { "content" => content } }] }
  end

  describe "#call" do
    it "accepts on a clean accept verdict" do
      allow(client_double).to receive(:chat)
        .and_return(response_with('{"decision": "accept", "reason": "Good fit"}'))
      result = service.call
      expect(result.accepted).to be(true)
      expect(result.reason).to eq("Good fit")
      expect(result.error).to be(false)
    end

    it "declines on a clean decline verdict (a genuine 'no', not an error)" do
      allow(client_double).to receive(:chat)
        .and_return(response_with('{"decision": "decline", "reason": "Not relevant"}'))
      result = service.call
      expect(result.accepted).to be(false)
      expect(result.reason).to eq("Not relevant")
      expect(result.error).to be(false)
    end

    it "flags an evaluation error (not a decline) on unparseable output" do
      allow(client_double).to receive(:chat).and_return(response_with("???"))
      result = service.call
      expect(result.accepted).to be(false)
      expect(result.error).to be(true)
      expect(result.reason).to eq(described_class::FALLBACK_REASON)
    end

    it "flags an evaluation error (not a decline) when the API raises" do
      allow(client_double).to receive(:chat).and_raise(StandardError, "boom")
      result = service.call
      expect(result.accepted).to be(false)
      expect(result.error).to be(true)
    end

    it "passes the recipient interests and the incoming pitch into the prompt" do
      expect(client_double).to receive(:chat) do |args|
        content = args[:parameters][:messages].map { |m| m[:content] }.join("\n")
        expect(content).to include("Only want investor intros")
        expect(content).to include("Can we meet about my startup?")
        response_with('{"decision": "decline", "reason": "no"}')
      end
      service.call
    end
  end
end
