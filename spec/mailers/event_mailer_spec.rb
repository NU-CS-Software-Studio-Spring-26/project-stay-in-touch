require "rails_helper"

RSpec.describe EventMailer, type: :mailer do
  let(:organizer) { create(:user, email: "organizer@example.com") }
  let(:event) do
    create(:event, user: organizer, title: "Coffee", medium: "coffee",
                   occurred_at: 1.day.from_now, people: [person])
  end

  describe "#calendar_invite timezone (#189)" do
    # 14:07 UTC == 09:07 America/Chicago (CDT). The recipient should see 9:07,
    # not a UTC-shifted time, once the event is stored at the correct instant.
    let(:event) do
      create(:event, user: organizer, title: "Coffee", medium: "coffee",
                     occurred_at: Time.utc(2026, 6, 5, 14, 7), people: [person])
    end
    let(:person) do
      create(:person, user: organizer, email: "chi@example.com", timezone: "America/Chicago")
    end

    it "writes the .ics start time in the recipient's zone" do
      mail = described_class.calendar_invite(event, person, organizer)
      ics  = mail.attachments["invite.ics"].body.to_s
      expect(ics).to include("DTSTART;TZID=America/Chicago:20260605T090700")
    end

    it "shows the local time in the subject" do
      mail = described_class.calendar_invite(event, person, organizer)
      expect(mail.subject).to include("9:07")
    end
  end

  describe "#calendar_invite" do
    context "when the invitee is not a registered user" do
      let(:person) { create(:person, user: organizer, email: "stranger@example.com") }

      it "encourages them to sign up" do
        mail = described_class.calendar_invite(event, person, organizer)
        expect(mail.body.encoded).to include("Join Serendipity")
      end
    end

    context "when the invitee is already a registered user" do
      let!(:invitee) { create(:user, email: "member@example.com") }
      let(:person)   { create(:person, user: organizer, email: "member@example.com") }

      it "does not show the sign-up nudge" do
        mail = described_class.calendar_invite(event, person, organizer)
        expect(mail.body.encoded).not_to include("Join Serendipity")
      end
    end
  end
end
