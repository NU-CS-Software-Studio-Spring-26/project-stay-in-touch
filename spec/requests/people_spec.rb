require "rails_helper"
require "tempfile"

RSpec.describe "People", type: :request do
  let(:user) { create(:user) }

  let(:valid_attrs) do
    {
      name: "Alice Tester",
      email: "alice.tester@example.com",
      timezone: "America/Chicago",
      preferred_start_hour: 9,
      preferred_end_hour: 21,
      frequency_weeks: 4.0,
      notes: "met at conference"
    }
  end

  let(:invalid_attrs) do
    valid_attrs.merge(email: "nope", name: "")
  end

  before { sign_in(user) }

  describe "GET /people" do
    it "renders the index" do
      create_list(:person, 3, user: user)
      get people_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("People")
    end

    it "does not show other users' people" do
      other_person = create(:person)
      get people_path
      expect(response.body).not_to include(other_person.name)
    end

    describe "the 'Time to reach out' panel (#184)" do
      def overdue_person!
        person = create(:person, user: user, frequency_weeks: 1.0)
        create(:event, user: user, people: [person], occurred_at: 100.days.ago)
        person
      end

      it "summarises the count and shows only the most-overdue few with a 'View all' link" do
        4.times { overdue_person! }
        get people_path
        expect(response.body).to include("4 people")
        expect(response.body).to include("are due for a catch-up")
        # Capped at 3 rows, not a wall of 4+ (panel-unique phrase)
        expect(response.body.scan("caught up with").size).to eq(3)
        expect(response.body).to include("View all 4")
      end

      it "omits the 'View all' link when 3 or fewer are overdue" do
        2.times { overdue_person! }
        get people_path
        expect(response.body).to include("2 people")
        expect(response.body).not_to include("View all")
      end
    end
  end

  describe "GET /people/:id" do
    it "renders the show page" do
      person = create(:person, user: user)
      get person_path(person)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(person.name)
    end

    it "redirects for another user's person" do
      other_person = create(:person)
      get person_path(other_person)
      expect(response).to redirect_to(root_path)
    end

    context "AI reconnect message card" do
      let(:person) { create(:person, user: user) }

      context "when OPENROUTER_API_KEY is set and the service returns a message" do
        before do
          stub_const("ENV", ENV.to_h.merge("OPENROUTER_API_KEY" => "sk-test"))
          allow_any_instance_of(ReconnectMessageService).to receive(:call).and_return("Hey, let's catch up!")
        end

        it "shows the AI message card" do
          get person_path(person)
          expect(response.body).to include("Hey, let&#39;s catch up!")
          expect(response.body).to include("AI-suggested message")
        end
      end

      context "when OPENROUTER_API_KEY is not set" do
        before do
          stub_const("ENV", ENV.to_h.except("OPENROUTER_API_KEY"))
        end

        it "omits the AI message card without error" do
          get person_path(person)
          expect(response).to have_http_status(:ok)
          expect(response.body).not_to include("AI-suggested message")
        end
      end

      context "when OPENROUTER_API_KEY is set but the service returns nil (API error)" do
        before do
          stub_const("ENV", ENV.to_h.merge("OPENROUTER_API_KEY" => "sk-test"))
          allow_any_instance_of(ReconnectMessageService).to receive(:call).and_return(nil)
        end

        it "omits the AI message card without error" do
          get person_path(person)
          expect(response).to have_http_status(:ok)
          expect(response.body).not_to include("AI-suggested message")
        end
      end
    end
  end

  describe "GET /people/new" do
    it "renders the form" do
      get new_person_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /people" do
    it "creates a person with valid params" do
      expect {
        post people_path, params: { person: valid_attrs }
      }.to change(Person, :count).by(1)
      expect(Person.last.user).to eq(user)
      expect(response).to redirect_to(person_path(Person.last))
    end

    it "re-renders new with invalid params" do
      expect {
        post people_path, params: { person: invalid_attrs }
      }.not_to change(Person, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /people/:id/edit" do
    it "renders the edit form" do
      person = create(:person, user: user)
      get edit_person_path(person)
      expect(response).to have_http_status(:ok)
    end

    it "wires up the dirty-form and tag-toggle Stimulus controllers" do
      person = create(:person, user: user) # user gets default tags on create
      get edit_person_path(person)
      expect(response.body).to include('data-controller="dirty-form"')
      expect(response.body).to include("You have unsaved changes")
      expect(response.body).to include('data-controller="tag-toggle"')
    end
  end

  describe "PATCH /people/:id" do
    it "updates with valid params" do
      person = create(:person, user: user, name: "Old Name")
      patch person_path(person), params: { person: { name: "New Name" } }
      expect(response).to redirect_to(person_path(person))
      expect(person.reload.name).to eq("New Name")
    end

    it "re-renders edit with invalid params" do
      person = create(:person, user: user)
      patch person_path(person), params: { person: { email: "bad" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /people/:id" do
    it "destroys the person" do
      person = create(:person, user: user)
      expect {
        delete person_path(person)
      }.to change(Person, :count).by(-1)
      expect(response).to redirect_to(people_path)
    end
  end

  describe "PATCH /people/:id/toggle_favorite" do
    it "toggles favorite from false to true" do
      person = create(:person, user: user, favorite: false)
      patch toggle_favorite_person_path(person)
      expect(person.reload.favorite).to be true
      expect(response).to be_redirect
    end

    it "toggles favorite from true to false" do
      person = create(:person, user: user, favorite: true)
      patch toggle_favorite_person_path(person)
      expect(person.reload.favorite).to be false
    end

    it "cannot toggle another user's person" do
      other_person = create(:person, favorite: false)
      patch toggle_favorite_person_path(other_person)
      expect(other_person.reload.favorite).to be false
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /people with favorites filter" do
    it "returns only favorites when ?favorites=1" do
      fav     = create(:person, user: user, favorite: true,  name: "Alice Fav")
      non_fav = create(:person, user: user, favorite: false, name: "Bob NonFav")
      get people_path(favorites: "1")
      expect(response.body).to include(fav.name)
      expect(response.body).not_to include(non_fav.name)
    end

    it "shows favorites first in the default list" do
      create(:person, user: user, favorite: false, name: "Aaron Zzz")
      fav = create(:person, user: user, favorite: true,  name: "Zara Aaa")
      get people_path
      expect(response.body.index(fav.name)).to be < response.body.index("Aaron Zzz")
    end
  end

  describe "POST /people/import" do
    def csv_upload(content, filename: "contacts.csv")
      file = Tempfile.new([ "upload", File.extname(filename) ])
      file.binmode
      file.write(content)
      file.rewind
      Rack::Test::UploadedFile.new(file.path, nil, original_filename: filename)
    end

    it "imports people from a valid CSV" do
      csv = "name,email\nJane Smith,jane@example.com\n"
      expect {
        post import_people_path, params: { csv_file: csv_upload(csv) }
      }.to change(user.people, :count).by(1)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Import complete")
    end

    it "rejects an unsupported file type without importing" do
      expect {
        post import_people_path, params: { csv_file: csv_upload("whatever", filename: "notes.txt") }
      }.not_to change(Person, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Unsupported file type")
    end

    it "rejects a file over the size limit without importing" do
      stub_const("CsvImportService::MAX_FILE_SIZE", 10)
      expect {
        post import_people_path, params: { csv_file: csv_upload("name,email\nJane,jane@example.com\n") }
      }.not_to change(Person, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("too large")
    end

    it "rejects a missing file" do
      post import_people_path
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Please select")
    end
  end

  describe "unauthenticated access" do
    before { delete logout_path }

    it "redirects GET /people to login" do
      get people_path
      expect(response).to redirect_to(login_path)
    end

    it "redirects POST /people to login" do
      post people_path, params: { person: valid_attrs }
      expect(response).to redirect_to(login_path)
    end
  end
end
