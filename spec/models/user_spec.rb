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

  describe "password reset" do
    let(:user) { create(:user) }

    describe "#generate_reset_token" do
      it "sets reset_token and reset_token_expires_at" do
        expect(user.reset_token).to be_nil
        expect(user.reset_token_expires_at).to be_nil

        raw_token = user.generate_reset_token

        expect(user.reset_token).to be_present
        expect(user.reset_token_expires_at).to be_present
        expect(user.reset_token_expires_at).to be_within(5.seconds).of(1.hour.from_now)
        expect(user.reset_token).not_to eq(raw_token)
      end
    end

    describe "#reset_token_valid?" do
      it "returns true for a valid, unexpired token" do
        raw_token = user.generate_reset_token
        expect(user.reset_token_valid?(raw_token)).to be true
      end

      it "returns false for an incorrect token" do
        user.generate_reset_token
        expect(user.reset_token_valid?("wrong-token")).to be false
      end

      it "returns false when token is expired" do
        user.generate_reset_token
        user.update!(reset_token_expires_at: 2.hours.ago)
        expect(user.reset_token_valid?("any-token")).to be false
      end

      it "returns false when no token exists" do
        expect(user.reset_token_valid?("any-token")).to be false
      end
    end

    describe "#clear_reset_token!" do
      it "removes the reset token" do
        user.generate_reset_token
        user.clear_reset_token!
        expect(user.reset_token).to be_nil
        expect(user.reset_token_expires_at).to be_nil
      end
    end
  end

  describe "matchmaking" do
    describe ".matchmaking_candidates" do
      it "includes opted-in users with interests" do
        ready = create(:user, :matchmaking_ready)
        expect(User.matchmaking_candidates).to include(ready)
      end

      it "excludes users who have not opted in" do
        not_opted = create(:user, meeting_interests: "things", matchmaking_enabled: false)
        expect(User.matchmaking_candidates).not_to include(not_opted)
      end

      it "excludes opted-in users with blank interests" do
        blank = create(:user, meeting_interests: "", matchmaking_enabled: true)
        expect(User.matchmaking_candidates).not_to include(blank)
      end
    end

    describe "#matchmaking_ready?" do
      it "is true when opted in with interests" do
        expect(build(:user, :matchmaking_ready)).to be_matchmaking_ready
      end

      it "is false when opted in but interests are blank" do
        expect(build(:user, matchmaking_enabled: true, meeting_interests: "")).not_to be_matchmaking_ready
      end

      it "is false when not opted in" do
        expect(build(:user, matchmaking_enabled: false, meeting_interests: "x")).not_to be_matchmaking_ready
      end
    end

    describe "#display_label" do
      it "uses display_name when present" do
        expect(build(:user, display_name: "Jordan").display_label).to eq("Jordan")
      end

      it "falls back to the email local-part" do
        expect(build(:user, display_name: nil, email: "sam@example.com").display_label).to eq("sam")
      end
    end
  end
end
