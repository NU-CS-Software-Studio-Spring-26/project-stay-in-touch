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

    describe "password complexity" do
      let(:base) { "Password1!" }

      it "is invalid when 10 characters or fewer" do
        pw = "Passw0rd!x"[0, 10]
        expect(build(:user, password: pw, password_confirmation: pw)).not_to be_valid
      end

      it "is invalid without an uppercase letter" do
        pw = "password1!secure"
        expect(build(:user, password: pw, password_confirmation: pw)).not_to be_valid
      end

      it "is invalid without a lowercase letter" do
        pw = "PASSWORD1!SECURE"
        expect(build(:user, password: pw, password_confirmation: pw)).not_to be_valid
      end

      it "is invalid without a number" do
        pw = "Password!!secure"
        expect(build(:user, password: pw, password_confirmation: pw)).not_to be_valid
      end

      it "is invalid without a special character" do
        pw = "Password1secure"
        expect(build(:user, password: pw, password_confirmation: pw)).not_to be_valid
      end

      it "is valid when all requirements are met" do
        pw = "Password1!secure"
        expect(build(:user, password: pw, password_confirmation: pw)).to be_valid
      end
    end
  end
end
