require "rails_helper"

RSpec.describe Person, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:event_participants).dependent(:destroy) }
    it { is_expected.to have_many(:events).through(:event_participants) }
  end

  describe "validations" do
    subject { build(:person) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to validate_presence_of(:timezone) }
    it { is_expected.to allow_value("America/Chicago").for(:timezone) }
    it { is_expected.not_to allow_value("Not/A_Zone").for(:timezone) }
    it { is_expected.to validate_numericality_of(:preferred_start_hour).only_integer.is_in(0..23) }

    it "validates preferred_end_hour is in 0..23" do
      # Use subject with start_hour=0 so the window-order rule doesn't trip the matcher.
      subject = build(:person, preferred_start_hour: 0)
      expect(subject).to validate_numericality_of(:preferred_end_hour).only_integer.is_in(0..23)
    end
    it { is_expected.to validate_numericality_of(:frequency_weeks).is_greater_than(0) }

    it "rejects malformed email" do
      person = build(:person, email: "not-an-email")
      expect(person).not_to be_valid
    end

    it "requires preferred_end_hour >= preferred_start_hour" do
      person = build(:person, preferred_start_hour: 20, preferred_end_hour: 8)
      expect(person).not_to be_valid
      expect(person.errors[:preferred_end_hour]).to be_present
    end
  end

  describe "#latest_event" do
    let(:person) { create(:person) }

    it "returns nil when no events" do
      expect(person.latest_event).to be_nil
    end

    it "returns the most recent event" do
      older  = create(:event, occurred_at: 2.weeks.ago, people: [person])
      newer  = create(:event, occurred_at: 3.days.ago,  people: [person])
      _other = create(:event, occurred_at: 1.day.ago, people: [create(:person)])
      expect(person.latest_event).to eq(newer)
      expect(person.latest_event).not_to eq(older)
    end
  end

  describe "#days_until_due" do
    let(:person) { create(:person, frequency_weeks: 2.0) }

    it "returns nil when no events" do
      expect(person.days_until_due).to be_nil
    end

    it "is negative when overdue" do
      create(:event, occurred_at: 30.days.ago, people: [person])
      expect(person.days_until_due).to be < 0
    end

    it "is positive when upcoming" do
      create(:event, occurred_at: 1.day.ago, people: [person])
      expect(person.days_until_due).to be > 0
    end
  end
end
