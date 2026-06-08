class AddCalendarEventLinkToEvents < ActiveRecord::Migration[8.1]
  def change
    # Capture the Google Calendar event Serendipity creates when an event is
    # scheduled, so the event page can link straight to it. Mirrors the
    # calendar_event_id / calendar_event_link columns on meeting_proposals.
    add_column :events, :calendar_event_id, :string
    add_column :events, :calendar_event_link, :string
  end
end
