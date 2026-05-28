require "rails_helper"

RSpec.describe Matchmaking::SecretaryPitchService, type: :service do
  let(:requester) do
    create(:user, :matchmaking_ready, display_name: "Requester",
           meeting_interests: "Looking for cofounder advice")
  end
  let(:cand_a) do
    create(:user, :matchmaking_ready, display_name: "Alice",
           email: "alice@example.com", meeting_interests: "Happy to mentor founders")
  end
  let(:cand_b) do
    create(:user, :matchmaking_ready, display_name: "Bob",
           email: "bob@example.com", meeting_interests: "Want running buddies")
  end
  let(:candidates) { [cand_a, cand_b] }

  subject(:service) { described_class.new(requester, candidates) }

  let(:client_double) { instance_double(OpenAI::Client) }
  before { allow(OpenAI::Client).to receive(:new).and_return(client_double) }

  def response_with(content)
    { "choices" => [{ "message" => { "content" => content } }] }
  end

  describe "#call" do
    it "returns the chosen candidate and pitch from clean JSON" do
      allow(client_double).to receive(:chat)
        .and_return(response_with('{"choice": 1, "pitch": "Hi Alice, let us talk!"}'))
      result = service.call
      expect(result.target_user).to eq(cand_a)
      expect(result.pitch_text).to eq("Hi Alice, let us talk!")
    end

    it "extracts JSON embedded in surrounding prose" do
      allow(client_double).to receive(:chat)
        .and_return(response_with('Sure thing! {"choice": 2, "pitch": "Hey Bob"} hope that helps'))
      expect(service.call.target_user).to eq(cand_b)
    end

    it "returns nil when the choice is out of range" do
      allow(client_double).to receive(:chat)
        .and_return(response_with('{"choice": 9, "pitch": "..."}'))
      expect(service.call).to be_nil
    end

    it "returns nil on unparseable output" do
      allow(client_double).to receive(:chat).and_return(response_with("no json here"))
      expect(service.call).to be_nil
    end

    it "returns nil when there are no candidates" do
      expect(described_class.new(requester, []).call).to be_nil
    end

    it "returns nil when the API raises" do
      allow(client_double).to receive(:chat).and_raise(StandardError, "boom")
      expect(service.call).to be_nil
    end

    it "includes display labels but never emails in the prompt" do
      expect(client_double).to receive(:chat) do |args|
        content = args[:parameters][:messages].map { |m| m[:content] }.join("\n")
        expect(content).to include("Alice").and include("Bob")
        expect(content).not_to include("alice@example.com")
        expect(content).not_to include("bob@example.com")
        response_with('{"choice": 1, "pitch": "hi"}')
      end
      service.call
    end
  end
end
