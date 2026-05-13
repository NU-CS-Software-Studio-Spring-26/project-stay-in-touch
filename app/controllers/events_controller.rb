class EventsController < ApplicationController
  before_action :set_event, only: %i[show edit update destroy]

  SORTABLE_COLUMNS = %w[date title medium participants].freeze

  def index
    @sort      = SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : "date"
    @direction = params[:direction] == "asc" ? "asc" : "desc"

    case @sort
    when "title"
      @pagy, @events = pagy(current_user.events.includes(:people)
                                         .order(Arel.sql("COALESCE(NULLIF(title, ''), medium) #{@direction}")))
    when "medium"
      @pagy, @events = pagy(current_user.events.includes(:people).order(medium: @direction))
    when "participants"
      sorted = current_user.events.includes(:people).sort_by { |e| e.people.map(&:name).min || "" }
      sorted = sorted.reverse if @direction == "asc"
      @pagy, @events = pagy_array(sorted)
    else
      @pagy, @events = pagy(current_user.events.includes(:people).order(occurred_at: @direction))
    end
  end

  def show; end

  def new
    @event  = current_user.events.build
    @people = current_user.people.order(:name)
  end

  def edit
    @people = current_user.people.order(:name)
  end

  def create
    @event = current_user.events.build(event_params)
    @event.occurred_at = find_scheduled_slot

    if @event.save
      push_to_google_calendar(@event) if current_user.google_calendar_connected?
      send_calendar_invites(@event)
      redirect_to @event, notice: "Catch-up scheduled!"
    else
      @people = current_user.people.order(:name)
      render :new, status: :unprocessable_content
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

    if current_user.google_calendar_connected?
      GoogleCalendarService.new(current_user)
                           .find_earliest_slot(
                             window_days:   window_days,
                             from_hour:     from_h,
                             to_hour:       to_h,
                             slot_duration: duration_min.minutes
                           )
    end || default_slot(window_days, from_h, from_m)
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
    GoogleCalendarService.new(current_user).push_event(event, people)
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
