require "rails_helper"

RSpec.describe ReconnectMessageService, type: :service do
  let(:user)   { create(:user) }
  let(:person) { create(:person, user: user, name: "Alice", notes: "met at conference") }

  subject(:service) { described_class.new(person, user) }

  let(:client_double) { instance_double(OpenAI::Client) }

  before do
    allow(OpenAI::Client).to receive(:new).and_return(client_double)
  end

  describe "#call" do
    context "when the API returns a message" do
      let(:fake_response) do
        {
          "choices" => [
            { "message" => { "content" => "  Hey Alice, hope you're well!  " } }
          ]
        }
      end

      before do
        allow(client_double).to receive(:chat).and_return(fake_response)
      end

      it "returns the stripped message string" do
        expect(service.call).to eq("Hey Alice, hope you're well!")
      end

      it "passes the person name in the prompt" do
        expect(client_double).to receive(:chat) do |args|
          expect(args[:parameters][:messages].first[:content]).to include("Alice")
          fake_response
        end
        service.call
      end

      context "when the person has a recent event" do
        before do
          event = create(:event, user: user, occurred_at: 10.days.ago, medium: "call")
          create(:event_participant, event: event, person: person)
        end

        it "includes days since last contact in the prompt" do
          expect(client_double).to receive(:chat) do |args|
            expect(args[:parameters][:messages].first[:content]).to include("days ago")
            fake_response
          end
          service.call
        end
      end

      context "when the person has no events" do
        it "builds a prompt without days-since-last-contact clause" do
          expect(client_double).to receive(:chat) do |args|
            expect(args[:parameters][:messages].first[:content]).not_to include("days ago")
            fake_response
          end
          service.call
        end
      end

      context "when the person has notes" do
        it "includes notes in the prompt" do
          expect(client_double).to receive(:chat) do |args|
            expect(args[:parameters][:messages].first[:content]).to include("met at conference")
            fake_response
          end
          service.call
        end
      end

      context "when the person has no notes" do
        let(:person) { create(:person, user: user, name: "Bob", notes: nil) }

        it "does not include a notes clause in the prompt" do
          expect(client_double).to receive(:chat) do |args|
            expect(args[:parameters][:messages].first[:content]).not_to include("Notes about them")
            fake_response
          end
          service.call
        end
      end
    end

    context "when the API raises a StandardError" do
      before do
        allow(client_double).to receive(:chat).and_raise(StandardError, "network timeout")
      end

      it "returns nil without raising" do
        expect(service.call).to be_nil
      end
    end

    context "when the response has no choices" do
      before do
        allow(client_double).to receive(:chat).and_return({})
      end

      it "returns nil" do
        expect(service.call).to be_nil
      end
    end
  end
end
