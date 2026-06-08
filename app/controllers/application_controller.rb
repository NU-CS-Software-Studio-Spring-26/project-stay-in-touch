class ApplicationController < ActionController::Base
  include Authentication
  include Pagy::Backend
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  # Run every request in the signed-in user's timezone so naive form input
  # (HTML5 datetime-local has no offset) is parsed in their zone and all
  # timezone-aware attributes render back in it. Without this the app default
  # (UTC) is used, so "9:07" entered by a Chicago user was stored as 9:07 UTC
  # and later shifted by 5h on the calendar invite (#188/#189/#96). The per-user
  # timezone preference is set at registration (browser-detected) and editable
  # in Settings; here we simply apply it. Falls back to the app default for
  # unauthenticated requests.
  around_action :use_user_time_zone

  private

  def use_user_time_zone(&block)
    Time.use_zone(current_user&.timezone.presence || Time.zone, &block)
  end

  def record_not_found
    redirect_to root_path, alert: "That record doesn't exist or has been deleted."
  end
end
