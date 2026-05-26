class PeopleController < ApplicationController
  before_action :set_person, only: %i[show edit update destroy snooze toggle_favorite toggle_tag]

  SORTABLE_COLUMNS = %w[name frequency status].freeze

  def index
    @sort = SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : "name"
    @direction = params[:direction] == "desc" ? "desc" : "asc"
    @favorites_filter = params[:favorites] == "1"
    @tag_filter = params[:tag_id].present? ? current_user.tags.find_by(id: params[:tag_id]) : nil
    @all_tags = current_user.tags.order(:name)

    people_scope = current_user.people.preload(:tags)
    people_scope = people_scope.where("LOWER(name) LIKE ?", "%#{params[:q].downcase}%") if params[:q].present?
    people_scope = people_scope.where(favorite: true) if @favorites_filter
    people_scope = people_scope.joins(:person_tags).where(person_tags: { tag_id: @tag_filter.id }) if @tag_filter

    case @sort
    when "frequency"
      @people_pagy, @people = pagy(people_scope.order(favorite: :desc, frequency_weeks: @direction))
    when "status"
      sorted = people_scope.includes(:events).sort_by { |p| p.days_until_due || -Float::INFINITY }
      sorted = sorted.reverse if @direction == "desc"
      sorted = sorted.partition { |p| p.favorite? }.flatten
      @people_pagy, @people = pagy_array(sorted)
    else
      @people_pagy, @people = pagy(people_scope.order(favorite: :desc, name: @direction))
    end

    @overdue_people = current_user.people.includes(:events)
                                  .select { |p| !p.snoozed? && p.days_until_due&.negative? }
                                  .sort_by { |p| p.days_until_due }
                                  .first(3)

    @upcoming_birthday_ids = current_user.people.where.not(birthday: nil).select { |p|
      bday = p.birthday.change(year: Date.current.year)
      bday = bday.next_year if bday < Date.current
      (bday - Date.current).to_i <= 30
    }.map(&:id).to_set
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

  def import
    return unless request.post?

    file = params[:csv_file]
    unless file
      flash.now[:alert] = "Please select a CSV file."
      return render :import, status: :unprocessable_content
    end

    @results = CsvImportService.new(file, current_user).call
  end

  def new
    @person = current_user.people.build
    @all_tags = current_user.tags.order(:name)
  end

  def edit
    @all_tags = current_user.tags.order(:name)
  end

  def create
    @person = current_user.people.build(person_params)
    if @person.save
      assign_new_tag_name
      redirect_to @person, notice: "Person was successfully created."
    else
      @all_tags = current_user.tags.order(:name)
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @person.update(person_params)
      assign_new_tag_name
      redirect_to @person, notice: "Person was successfully updated."
    else
      @all_tags = current_user.tags.order(:name)
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @person.destroy
    redirect_to people_path, notice: "Person was successfully deleted.", status: :see_other
  end

  def snooze
    @person.update!(snoozed_until: params[:snoozed_until].presence)
    redirect_back fallback_location: person_path(@person), notice: @person.snoozed? ? "Snoozed until #{@person.snoozed_until}." : "Snooze cleared."
  end

  def toggle_favorite
    @person.update!(favorite: !@person.favorite?)
    redirect_back fallback_location: person_path(@person)
  end

  def toggle_tag
    tag = current_user.tags.find(params[:tag_id])
    if @person.tags.include?(tag)
      @person.tags.delete(tag)
    else
      @person.tags << tag
    end
    redirect_back fallback_location: person_path(@person)
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
      :favorite,
      :notes,
      :birthday,
      tag_ids: []
    )
  end

  def assign_new_tag_name
    raw = params.dig(:person, :new_tag_name).to_s.strip
    return if raw.blank?

    tag = current_user.tags.find_or_create_by!(name: raw)
    @person.tags << tag unless @person.tags.include?(tag)
  end
end
