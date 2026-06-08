class PeopleController < ApplicationController
  before_action :set_person, only: %i[show edit update destroy snooze toggle_favorite toggle_tag notes_edit]
  before_action :load_all_tags, only: %i[index new edit]

  SORTABLE_COLUMNS = %w[name frequency status].freeze

  def index
    @sort = SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : "name"
    @direction = params[:direction] == "desc" ? "desc" : "asc"
    @favorites_filter = params[:favorites] == "1"
    @tag_filter = params[:tag_id].present? ? current_user.tags.find_by(id: params[:tag_id]) : nil

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

    # "Time to reach out" — summarise rather than list everyone (#184). We keep the
    # full count for the headline and show only the most-overdue few, with a
    # "View all" link to the status-sorted table for the rest.
    overdue = current_user.people.includes(:events)
                          .select(&:overdue?)
                          .sort_by(&:days_until_due)
    @overdue_count  = overdue.size
    @overdue_people = overdue.first(3)

    @upcoming_birthday_ids = current_user.people.where.not(birthday: nil)
      .select(&:birthday_within?)
      .map(&:id).to_set
  end

  def show
    @events = @person.events.recent
    @facts  = @person.person_facts.order(created_at: :desc)
    @contact_link  = @person.contact_link
    @linked_person = @person.linked_person
    @shared_events = if @linked_person
      Event.joins(:event_participants)
           .where(event_participants: { person_id: [@person.id, @linked_person.id] })
           .includes(:user, :people)
           .distinct
           .order(occurred_at: :desc)
    end
    @suggested_times = if current_user.google_calendar_connected?
      GoogleCalendarService.new(current_user).suggest_times(@person)
    else
      []
    end
    if ENV["OPENROUTER_API_KEY"].present?
      @suggested_message = ReconnectMessageService.new(@person, current_user).call
    end
  end

  def export
    people = current_user.people.preload(:tags, :events).order(:name)
    csv_data = CSV.generate(headers: true) do |csv|
      csv << %w[Name Email Tags Last\ Contact\ Date]
      people.each do |person|
        csv << [
          person.name,
          person.email,
          person.tags.map(&:name).join("; "),
          person.latest_event&.occurred_at&.to_date
        ]
      end
    end
    send_data csv_data,
              filename: "contacts-#{Date.current}.csv",
              type: "text/csv",
              disposition: "attachment"
  end

  def import
    return unless request.post?

    file = params[:csv_file]
    unless file.respond_to?(:read)
      flash.now[:alert] = "Please select a CSV or vCard file."
      return render :import, status: :unprocessable_content
    end

    unless CsvImportService.allowed_file?(file)
      flash.now[:alert] = "Unsupported file type. Please upload a .csv or .vcf file."
      return render :import, status: :unprocessable_content
    end

    if file.size > CsvImportService::MAX_FILE_SIZE
      max_mb = CsvImportService::MAX_FILE_SIZE / 1.megabyte
      flash.now[:alert] = "That file is too large (max #{max_mb} MB)."
      return render :import, status: :unprocessable_content
    end

    @results = CsvImportService.new(file, current_user).call
  end

  def new
    @person = current_user.people.build
  end

  def edit
  end

  def create
    @person = current_user.people.build(person_params)
    if @person.save
      assign_new_tag_name
      redirect_to @person, notice: "Person was successfully created."
    else
      load_all_tags
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @person.update(person_params)
      assign_new_tag_name
      if params[:inline_notes]
        redirect_to @person
      else
        redirect_to @person, notice: "Person was successfully updated."
      end
    else
      if params[:inline_notes]
        render "notes_edit"
      else
        load_all_tags
        render :edit, status: :unprocessable_content
      end
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

  def notes_edit
    render "notes_edit"
  end

  private

  def set_person
    @person = current_user.people.find(params[:id])
  end

  def load_all_tags
    @all_tags = current_user.tags.order(:name)
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
