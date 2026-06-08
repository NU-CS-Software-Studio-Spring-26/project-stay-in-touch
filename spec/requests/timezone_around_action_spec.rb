require "rails_helper"

# Directly exercises ApplicationController#use_user_time_zone, the around_action
# added for #188/#189/#96. The timezone behaviour is also proven end-to-end by
# the event specs, but this isolates the callback itself: any authenticated
# request — regardless of the feature it hits — should run inside
# current_user.timezone. We capture Time.zone *during* the controller action
# (the around_action restores it afterwards) and assert it tracks the user.
RSpec.describe "Per-request timezone (around_action)", type: :request do
  def captured_zone_for(user)
    sign_in(user)
    zone = nil
    allow_any_instance_of(DashboardController).to receive(:index).and_wrap_original do |original, *args|
      zone = Time.zone.name
      original.call(*args)
    end
    get root_path
    zone
  end

  it "runs an authenticated request in the signed-in user's timezone" do
    user = create(:user, timezone: "Asia/Tokyo")
    expect(captured_zone_for(user)).to eq("Asia/Tokyo")
    expect(response).to have_http_status(:ok)
  end

  it "tracks the user's zone rather than a hardcoded default" do
    user = create(:user, timezone: "Europe/London")
    expect(captured_zone_for(user)).to eq("Europe/London")
  end
end
