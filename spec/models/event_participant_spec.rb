require "rails_helper"

RSpec.describe EventParticipant, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:person) }
    it { is_expected.to belong_to(:event) }
  end

  describe "validations" do
    it "forbids the same person on the same event twice" do
      person = create(:person)
      event  = create(:event, people: [person])
      dup    = EventParticipant.new(person: person, event: event)
      expect(dup).not_to be_valid
      expect(dup.errors[:person_id]).to be_present
    end

    it "allows the same person across different events" do
      person  = create(:person)
      event_a = create(:event, people: [person])
      event_b = create(:event)
      ep      = EventParticipant.new(person: person, event: event_b)
      expect(ep).to be_valid
      expect(event_a).to be_valid
    end
  end
end
