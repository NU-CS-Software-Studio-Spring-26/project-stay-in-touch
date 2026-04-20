# Standard REST controller for Event. The one non-obvious piece:
# the Event form in app/views/events/_form.html.erb submits a list of
# `event[person_ids][]` values (one per checked Person). Rails maps that
# array directly onto the has_many :through participants association
# during Event.new / Event#update.
class EventsController < ApplicationController
  before_action :set_event, only: %i[show edit update destroy]

  def index
    @events = Event.recent.includes(:people)
  end

  def show; end

  def new
    @event = Event.new(occurred_at: Time.current)
  end

  def edit; end

  def create
    @event = Event.new(event_params)
    if @event.save
      redirect_to @event, notice: "Event was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @event.update(event_params)
      redirect_to @event, notice: "Event was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @event.destroy
    redirect_to events_path, notice: "Event was successfully deleted.", status: :see_other
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  def event_params
    # `person_ids: []` is the ActiveRecord idiom for has_many :through assignment.
    # Blank values come in as [""] from unchecked boxes; compact them out.
    permitted = params.require(:event).permit(
      :occurred_at,
      :medium,
      :title,
      :notes,
      person_ids: []
    )
    permitted[:person_ids] = Array(permitted[:person_ids]).reject(&:blank?)
    permitted
  end
end
