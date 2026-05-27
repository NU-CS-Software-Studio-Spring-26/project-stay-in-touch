require "rails_helper"

RSpec.describe CsvImportService do
  let(:user) { create(:user) }

  # Minimal stand-in for an uploaded file: the service only needs #read and
  # #original_filename.
  def upload(content, filename: "contacts.csv")
    instance_double("ActionDispatch::Http::UploadedFile", read: content, original_filename: filename)
  end

  describe ".allowed_file?" do
    it "accepts .csv and .vcf (any case)" do
      expect(described_class.allowed_file?(upload("", filename: "a.csv"))).to be true
      expect(described_class.allowed_file?(upload("", filename: "a.CSV"))).to be true
      expect(described_class.allowed_file?(upload("", filename: "a.vcf"))).to be true
    end

    it "rejects other extensions and a missing filename" do
      expect(described_class.allowed_file?(upload("", filename: "a.txt"))).to be false
      expect(described_class.allowed_file?(upload("", filename: "a.exe"))).to be false
      expect(described_class.allowed_file?(upload("", filename: ""))).to be false
    end
  end

  describe "#call" do
    it "creates people from a simple CSV" do
      csv = "name,email,frequency_weeks\nJane Smith,jane@example.com,2\nJohn Doe,john@example.com,4\n"
      result = nil
      expect { result = described_class.new(upload(csv), user).call }
        .to change(user.people, :count).by(2)
      expect(result.created).to eq(2)
      expect(result.errors).to be_empty
    end

    it "refuses files with more rows than MAX_ROWS and imports nothing" do
      stub_const("CsvImportService::MAX_ROWS", 2)
      rows = (1..3).map { |n| "Person #{n},p#{n}@example.com" }.join("\n")
      csv  = "name,email\n#{rows}\n"

      result = nil
      expect { result = described_class.new(upload(csv), user).call }
        .not_to change(Person, :count)
      expect(result.created).to eq(0)
      expect(result.errors.first).to match(/maximum is 2/)
    end
  end
end
