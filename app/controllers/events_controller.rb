class EventsController < ApplicationController
  before_action :set_event, only: %i[show edit update destroy sync_calendar]

  SORTABLE_COLUMNS = %w[date title medium participants].freeze

  def index
    @event_months = current_user.events
                                .pluck(:occurred_at)
                                .map { |t| t.to_date.beginning_of_month }
                                .uniq
                                .sort
                                .reverse

    @current_month = if params[:month].present?
      year, mon = params[:month].split("-").map(&:to_i)
      Date.new(year, mon, 1)
    else
      Date.current.beginning_of_month
    end

    events_scope = current_user.events.where(
      occurred_at: @current_month.beginning_of_month.beginning_of_day..@current_month.end_of_month.end_of_day
    )

    if params[:q].present?
      q = "%#{params[:q].downcase}%"
      events_scope = events_scope
        .joins("LEFT JOIN event_participants ep ON ep.event_id = events.id LEFT JOIN people ON people.id = ep.person_id")
        .where("LOWER(COALESCE(events.title, '')) LIKE ? OR LOWER(events.medium) LIKE ? OR LOWER(people.name) LIKE ?", q, q, q)
        .distinct
    end

    ordered = events_scope.includes(:people).order(occurred_at: :asc)
    @pagy, @paged_events = pagy(ordered, items: 25)
    @events = ordered
    @events_by_day = @events.group_by { |e| e.occurred_at.to_date }

    # Serendipity's AI matchmaking books accepted matches straight onto Google
    # Calendar (it creates no local Event record), so surface this month's
    # AI-scheduled meetings here with a link to the calendar event it created.
    @serendipity_meetings = MeetingProposal.for_user(current_user)
                                           .accepted
                                           .where(calendar_created: true)
                                           .where(meeting_at: @current_month.beginning_of_month.beginning_of_day..@current_month.end_of_month.end_of_day)
                                           .order(:meeting_at)
  end

  def show; end

  def new
    @event  = current_user.events.build
    @event.occurred_at = params[:occurred_at] if params[:occurred_at].present?
    if params[:person_id].present? && current_user.people.exists?(params[:person_id])
      @event.person_ids = [params[:person_id]]
      @person = current_user.people.includes(:events).find(params[:person_id])
      @topic_suggestions = TopicSuggestionService.new(@person).call
    end
    @people = current_user.people.order(:name)
  end

  def edit
    @people = current_user.people.order(:name)
  end

  def create
    @event = current_user.events.build(event_params)
    @event.occurred_at = params[:quick_log] == "1" ? event_params[:occurred_at] : find_scheduled_slot

    if @event.save
      push_to_google_calendar(@event) if current_user.google_calendar_connected?
      send_calendar_invites(@event)

      if params[:quick_log] == "1"
        redirect_to request.referer || root_path, notice: "Catch-up logged!"
      else
        redirect_to @event, notice: "Catch-up scheduled!"
      end
    else
      @people = current_user.people.order(:name)
      @person = current_user.people.find_by(id: params.dig(:event, :person_ids)&.first)
      if params[:quick_log] == "1"
        # The quick-log modal posts with turbo_frame "_top", so a plain `render :new`
        # would replace the whole page with a bare frame fragment and the error would
        # never be seen (R1, rhymes with #190). Re-render the modal — which includes
        # its own error alert — in place via a Turbo Stream instead.
        render turbo_stream: turbo_stream.update("quick-log-modal", partial: "events/quick_log_modal"),
               status: :unprocessable_content
      else
        render :new, status: :unprocessable_content
      end
    end
  end

  def update
    if @event.update(event_params)
      redirect_to @event, notice: "Event was successfully updated."
    else
      @people = current_user.people.order(:name)
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @event.destroy
    redirect_to root_path, notice: "Event was successfully deleted.", status: :see_other
  end

  # Push an already-logged event to Google Calendar on demand and store the
  # resulting event link. Lets events created before the link was captured (or
  # before the user connected Google) gain an "Open in Google Calendar" link.
  def sync_calendar
    unless current_user.google_calendar_connected?
      redirect_to @event, alert: "Connect Google Calendar on Settings first." and return
    end

    push_to_google_calendar(@event)

    if @event.calendar_event_link.present?
      redirect_to @event, notice: "Added to Google Calendar."
    else
      redirect_to @event, alert: "Couldn't add to Google Calendar — please try again."
    end
  end

  private

  def set_event
    @event = current_user.events.find(params[:id])
  end

  def find_scheduled_slot
    window_days  = params.dig(:event, :window_days).to_i
    window_days  = 3 if window_days < 1

    duration_min = params.dig(:event, :duration_minutes).to_i
    duration_min = 60 if duration_min < 15

    from_h, from_m = parse_time_param(params.dig(:event, :preferred_from))
    to_h,   _to_m  = parse_time_param(params.dig(:event, :preferred_to))
    to_h = [to_h, from_h + 1].max

    busy = collect_busy_intervals(window_days)
    slot = if busy
      GoogleCalendarService.earliest_free_slot(
        busy:          busy,
        window_days:   window_days,
        from_hour:     from_h,
        to_hour:       to_h,
        slot_duration: duration_min.minutes
      )
    end

    slot || default_slot(window_days, from_h, from_m)
  end

  # Merged free/busy from the organizer's calendar plus every invited Person who
  # is also a registered user with Google Calendar connected (issue #90). Returns
  # nil when no calendars are available, so scheduling falls back to default_slot
  # exactly as before.
  def collect_busy_intervals(window_days)
    calendar_users = []
    calendar_users << current_user if current_user.google_calendar_connected?
    calendar_users.concat(matched_invitee_users)
    return nil if calendar_users.empty?

    calendar_users.flat_map do |u|
      GoogleCalendarService.new(u).busy_intervals(window_days: window_days)
    end
  end

  # Registered users (other than the organizer) behind the invited People,
  # matched by email, who have connected Google Calendar. Each is queried with
  # its own credential, so only free/busy windows are read — never event detail.
  def matched_invitee_users
    emails = @event.people.filter_map { |p| p.email&.strip&.downcase }
    return [] if emails.empty?

    User.where(email: emails)
        .where.not(id: current_user.id)
        .includes(:google_credential)
        .select(&:google_calendar_connected?)
  end

  def parse_time_param(val)
    return [9, 0] if val.blank?
    parts = val.split(":").map(&:to_i)
    [parts[0].clamp(0, 23), (parts[1] || 0).clamp(0, 59)]
  end

  def default_slot(window_days, from_h, from_m)
    (Time.current.beginning_of_day + 1.day + from_h.hours + from_m.minutes)
      .ceil(15.minutes)
  end

  def push_to_google_calendar(event)
    people = event.people.to_a
    gcal_event = GoogleCalendarService.new(current_user).push_event(event, people)
    return unless gcal_event.respond_to?(:html_link)

    # Stamp the calendar link/id so the event page can link straight to it.
    # update_columns: the event is already saved and valid — just metadata.
    event.update_columns(
      calendar_event_id:   gcal_event.id,
      calendar_event_link: gcal_event.html_link
    )
  rescue StandardError => e
    Rails.logger.warn("GoogleCalendarService failed for event #{event.id}: #{e.message}")
  end

  def send_calendar_invites(event)
    event.people.each do |person|
      next if person.email.blank?
      EventMailer.calendar_invite(event, person, current_user).deliver_later
    end
  rescue StandardError => e
    Rails.logger.warn("send_calendar_invites failed for event #{event.id}: #{e.message}")
  end

  def event_params
    permitted = params.require(:event).permit(
      :occurred_at,
      :duration_minutes,
      :medium,
      :title,
      :notes,
      person_ids: []
    )
    permitted[:person_ids] = sanitize_person_ids(Array(permitted[:person_ids]).reject(&:blank?))
    permitted
  end

  def sanitize_person_ids(ids)
    current_user.people.where(id: ids).pluck(:id).map(&:to_s)
  end
end
