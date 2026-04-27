require "rails_helper"

RSpec.describe User, type: :model do
  subject { build(:user) }

  describe "associations" do
    it { is_expected.to have_many(:sessions).dependent(:destroy) }
    it { is_expected.to have_many(:people).dependent(:destroy) }
    it { is_expected.to have_many(:events).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }

    it "requires a valid email format" do
      expect(build(:user, email: "not-an-email")).not_to be_valid
    end

    it "normalizes email to lowercase" do
      user = create(:user, email: "Test@Example.COM")
      expect(user.reload.email).to eq("test@example.com")
    end

    it "requires password of at least 12 characters" do
      expect(build(:user, password: "tooshort123", password_confirmation: "tooshort123")).not_to be_valid
    end

    it "is valid with a 12-character password" do
      expect(build(:user, password: "password12345", password_confirmation: "password12345")).to be_valid
    end
  end
end
