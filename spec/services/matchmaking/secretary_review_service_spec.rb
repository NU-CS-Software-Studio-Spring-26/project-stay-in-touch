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
    end

    it "declines on a clean decline verdict" do
      allow(client_double).to receive(:chat)
        .and_return(response_with('{"decision": "decline", "reason": "Not relevant"}'))
      result = service.call
      expect(result.accepted).to be(false)
      expect(result.reason).to eq("Not relevant")
    end

    it "declines (fail-safe) on unparseable output" do
      allow(client_double).to receive(:chat).and_return(response_with("???"))
      expect(service.call.accepted).to be(false)
    end

    it "declines (fail-safe) when the API raises" do
      allow(client_double).to receive(:chat).and_raise(StandardError, "boom")
      expect(service.call.accepted).to be(false)
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
