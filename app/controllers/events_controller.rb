class EventsController < ApplicationController
  before_action :set_event, only: %i[show edit update destroy]

  SORTABLE_COLUMNS = %w[date title medium participants].freeze

  def index
    @sort      = SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : "date"
    @direction = params[:direction] == "asc" ? "asc" : "desc"

    case @sort
    when "title"
      @events = current_user.events.includes(:people)
                            .order(Arel.sql("COALESCE(NULLIF(title, ''), medium) #{@direction}"))
    when "medium"
      @events = current_user.events.includes(:people).order(medium: @direction)
    when "participants"
      events = current_user.events.includes(:people).sort_by { |e| e.people.map(&:name).min || "" }
      @events = @direction == "asc" ? events : events.reverse
    else
      @events = current_user.events.includes(:people).order(occurred_at: @direction)
    end
  end

  def show; end

  def new
    @event = current_user.events.build(occurred_at: Time.current)
    @people = current_user.people.order(:name)
  end

  def edit
    @people = current_user.people.order(:name)
  end

  def create
    @event = current_user.events.build(event_params)
    if @event.save
      push_to_google_calendar(@event) if current_user.google_calendar_connected?
      redirect_to @event, notice: "Event was successfully created."
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
    redirect_to events_path, notice: "Event was successfully deleted.", status: :see_other
  end

  private

  def set_event
    @event = current_user.events.find(params[:id])
  end

  def push_to_google_calendar(event)
    people = event.people.to_a
    GoogleCalendarService.new(current_user).push_event(event, people)
  rescue StandardError => e
    Rails.logger.warn("GoogleCalendarService failed for event #{event.id}: #{e.message}")
  end

  def event_params
    permitted = params.require(:event).permit(
      :occurred_at,
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
