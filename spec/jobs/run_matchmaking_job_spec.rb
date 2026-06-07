require "rails_helper"

RSpec.describe RunMatchmakingJob, type: :job do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("OPENROUTER_API_KEY").and_return("test-key")
    # Don't really sleep between batch rounds.
    allow(OpenRouterChat).to receive(:pause)
  end

  describe "#perform" do
    it "does nothing when the API key is absent" do
      allow(ENV).to receive(:[]).with("OPENROUTER_API_KEY").and_return(nil)
      create(:user, :matchmaking_ready)
      expect(Matchmaking::RoundOrchestratorService).not_to receive(:new)
      described_class.new.perform
    end

    it "runs the orchestrator for each opted-in candidate" do
      ready_a = create(:user, :matchmaking_ready)
      ready_b = create(:user, :matchmaking_ready)
      create(:user, matchmaking_enabled: false) # excluded from the pool

      orchestrator = instance_double(Matchmaking::RoundOrchestratorService, call: nil)
      expect(Matchmaking::RoundOrchestratorService).to receive(:new).with(ready_a).and_return(orchestrator)
      expect(Matchmaking::RoundOrchestratorService).to receive(:new).with(ready_b).and_return(orchestrator)

      described_class.new.perform
    end

    it "runs only the given user when a user_id is passed" do
      ready_a = create(:user, :matchmaking_ready)
      create(:user, :matchmaking_ready) # should be ignored

      orchestrator = instance_double(Matchmaking::RoundOrchestratorService, call: nil)
      expect(Matchmaking::RoundOrchestratorService).to receive(:new).once.with(ready_a).and_return(orchestrator)

      described_class.new.perform(ready_a.id)
    end

    it "spaces out rounds in the batch but not for a single user" do
      ready_a = create(:user, :matchmaking_ready)
      ready_b = create(:user, :matchmaking_ready)
      orchestrator = instance_double(Matchmaking::RoundOrchestratorService, call: nil)
      allow(Matchmaking::RoundOrchestratorService).to receive(:new).and_return(orchestrator)

      described_class.new.perform # batch: two users -> one pause between them
      expect(OpenRouterChat).to have_received(:pause).once

      described_class.new.perform(ready_a.id) # single user -> no extra pause
      expect(OpenRouterChat).to have_received(:pause).once
    end

    it "continues past a per-user failure" do
      ready_a = create(:user, :matchmaking_ready)
      ready_b = create(:user, :matchmaking_ready)

      failing = instance_double(Matchmaking::RoundOrchestratorService)
      allow(failing).to receive(:call).and_raise(StandardError, "boom")
      ok = instance_double(Matchmaking::RoundOrchestratorService, call: nil)

      allow(Matchmaking::RoundOrchestratorService).to receive(:new).with(ready_a).and_return(failing)
      allow(Matchmaking::RoundOrchestratorService).to receive(:new).with(ready_b).and_return(ok)

      expect { described_class.new.perform }.not_to raise_error
      expect(ok).to have_received(:call)
      # The failing user's round records an :error proposal so the user can see
      # it on the Matches page instead of nothing happening.
      expect(MeetingProposal.where(requester: ready_a, status: :error).count).to eq(1)
    end
  end
end
