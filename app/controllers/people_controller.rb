# Standard REST controller for Person. Nothing clever here — the show page
# pulls Person#events (via the EventParticipant join) for the timeline
# section, and the index sorts alphabetically by name.
class PeopleController < ApplicationController
  before_action :set_person, only: %i[show edit update destroy]

  SORTABLE_COLUMNS = %w[name frequency status].freeze

  def index
    @sort = SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : "name"
    @direction = params[:direction] == "desc" ? "desc" : "asc"

    case @sort
    when "frequency"
      @people = Person.order(frequency_weeks: @direction)
    when "status"
      people = Person.includes(:events).sort_by { |p| p.days_until_due || -Float::INFINITY }
      @people = @direction == "desc" ? people.reverse : people
    else
      @people = Person.order(name: @direction)
    end
  end

  def show
    @events = @person.events.recent
  end

  def new
    @person = Person.new
  end

  def edit; end

  def create
    @person = Person.new(person_params)
    if @person.save
      redirect_to @person, notice: "Person was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @person.update(person_params)
      redirect_to @person, notice: "Person was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @person.destroy
    redirect_to people_path, notice: "Person was successfully deleted.", status: :see_other
  end

  private

  def set_person
    @person = Person.find(params[:id])
  end

  def person_params
    params.require(:person).permit(
      :name,
      :email,
      :timezone,
      :preferred_start_hour,
      :preferred_end_hour,
      :frequency_weeks,
      :notes
    )
  end
end
