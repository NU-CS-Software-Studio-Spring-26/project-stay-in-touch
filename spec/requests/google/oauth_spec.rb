require "rails_helper"

RSpec.describe "Google::Oauth", type: :request do
  let(:user) { create(:user) }

  before { sign_in(user) }

  describe "PATCH /google/calendar_choice" do
    context "when Google Calendar is connected" do
      before { create(:google_credential, user: user) }

      it "stores the chosen availability calendars and redirects to settings" do
        patch google_calendar_choice_path,
          params: { availability_calendar_ids: ["work@example.com", "home@example.com"] }

        expect(response).to redirect_to(edit_settings_path)
        expect(user.google_credential.reload.availability_calendar_ids)
          .to eq(["work@example.com", "home@example.com"])
      end

      it "drops blank entries from the submitted list" do
        patch google_calendar_choice_path,
          params: { availability_calendar_ids: ["", "work@example.com"] }

        expect(user.google_credential.reload.availability_calendar_ids).to eq(["work@example.com"])
      end

      it "clears the selection (back to primary default) when nothing is submitted" do
        user.google_credential.update!(availability_calendar_ids: ["work@example.com"])

        patch google_calendar_choice_path, params: {}

        credential = user.google_credential.reload
        expect(credential.availability_calendar_ids).to eq([])
        expect(credential.conflict_calendar_ids).to eq(["primary"])
      end
    end

    context "when Google Calendar is not connected" do
      it "redirects to settings with an alert" do
        patch google_calendar_choice_path,
          params: { availability_calendar_ids: ["work@example.com"] }

        expect(response).to redirect_to(edit_settings_path)
        expect(flash[:alert]).to be_present
      end
    end
  end
end
