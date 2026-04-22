require "rails_helper"

RSpec.describe Event, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:event_participants).dependent(:destroy) }
    it { is_expected.to have_many(:people).through(:event_participants) }
  end

  describe "validations" do
    subject { build(:event) }

    it { is_expected.to validate_presence_of(:occurred_at) }
    it { is_expected.to validate_presence_of(:medium) }
    it { is_expected.to validate_inclusion_of(:medium).in_array(Event::MEDIA) }

    it "accepts occurred_at in the future" do
      event = build(:event, occurred_at: 1.day.from_now)
      expect(event).to be_valid
    end

    it "requires at least one person" do
      event = Event.new(occurred_at: 1.day.ago, medium: "call")
      expect(event).not_to be_valid
      expect(event.errors[:base]).to include("must include at least one person")
    end

    it "is valid with multiple people" do
      people = create_list(:person, 3)
      event  = build(:event, people: people)
      expect(event).to be_valid
    end
  end

  describe ".recent" do
    it "orders by occurred_at desc" do
      old_event = create(:event, occurred_at: 30.days.ago)
      new_event = create(:event, occurred_at: 1.day.ago)
      expect(Event.recent.to_a).to eq([new_event, old_event])
    end
  end

  describe "#display_title" do
    it "returns title when present" do
      event = build(:event, title: "Birthday dinner", occurred_at: Time.zone.local(2026, 1, 5))
      expect(event.display_title).to eq("Birthday dinner")
    end

    it "falls back to medium + date when title blank" do
      event = build(:event, title: "", medium: "call", occurred_at: Time.zone.local(2026, 1, 5))
      expect(event.display_title).to eq("Call on 2026-01-05")
    end
  end
end
