class AddCalendarIdsToGoogleCredentials < ActiveRecord::Migration[8.1]
  def change
    # The dedicated app-created "Serendipity" calendar this user's events are
    # written to (calendar.app.created scope). Null until the first write creates it.
    add_column :google_credentials, :serendipity_calendar_id, :string

    # Calendly-style "check for conflicts with" — a JSON-serialized list of calendar
    # ids whose free/busy is read when scheduling. Null/empty means "default to primary".
    add_column :google_credentials, :availability_calendar_ids, :text
  end
end
