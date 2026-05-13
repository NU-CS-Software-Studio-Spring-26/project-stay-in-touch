class PeopleController < ApplicationController
  before_action :set_person, only: %i[show edit update destroy]

  SORTABLE_COLUMNS = %w[name frequency status].freeze

  def index
    @sort = SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : "name"
    @direction = params[:direction] == "desc" ? "desc" : "asc"

    people_scope = current_user.people
    if params[:q].present?
      people_scope = people_scope.where("LOWER(name) LIKE ?", "%#{params[:q].downcase}%")
    end

    case @sort
    when "frequency"
      @people_pagy, @people = pagy(people_scope.order(frequency_weeks: @direction))
    when "status"
      sorted = people_scope.includes(:events).sort_by { |p| p.days_until_due || -Float::INFINITY }
      sorted = sorted.reverse if @direction == "desc"
      @people_pagy, @people = pagy_array(sorted)
    else
      @people_pagy, @people = pagy(people_scope.order(name: @direction))
    end

    @overdue_people = current_user.people.includes(:events)
                                  .select { |p| p.days_until_due&.negative? }
                                  .sort_by { |p| p.days_until_due }
                                  .first(3)
  end

  def show
    @events = @person.events.recent
    @suggested_times = if current_user.google_calendar_connected?
      GoogleCalendarService.new(current_user).suggest_times(@person)
    else
      []
    end
    if ENV["OPENROUTER_API_KEY"].present?
      @suggested_message = ReconnectMessageService.new(@person, current_user).call
    end
  end

  def new
    @person = current_user.people.build
  end

  def edit; end

  def create
    @person = current_user.people.build(person_params)
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
    @person = current_user.people.find(params[:id])
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
