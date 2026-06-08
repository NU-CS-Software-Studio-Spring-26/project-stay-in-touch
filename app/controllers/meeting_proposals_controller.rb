# The "Matches" page: AI-negotiated meeting proposals the current user is party to,
# on either side. The for_user scope is also the authorization boundary — a user can
# only see (and #find) proposals where they are the requester or the recipient.
class MeetingProposalsController < ApplicationController
  def index
    @proposals = MeetingProposal.visible_to(current_user)
                                .includes(:requester, :recipient)
                                .recent
  end

  def show
    @proposal = MeetingProposal.for_user(current_user)
                               .includes(:requester, :recipient)
                               .find(params[:id])
  end

  # Remove a match from the current user's Matches screen. Per-viewer: the other
  # party still sees it. for_user scopes the lookup so a user can only dismiss
  # their own matches (anything else 404s -> root redirect).
  def dismiss
    proposal = MeetingProposal.for_user(current_user).find(params[:id])
    proposal.dismiss_for(current_user)
    redirect_to matches_path, notice: "Match dismissed."
  end

  # One-click add the other party of a match to the current user's People list.
  # No-ops gracefully if they're already a contact (email is unique per user).
  def add_to_people
    proposal = MeetingProposal.for_user(current_user).find(params[:id])
    other    = proposal.other_party(current_user)
    return redirect_to(matches_path, alert: "This match has no one to add.") if other.nil?

    existing = current_user.people.where("LOWER(email) = ?", other.email.downcase).first
    if existing
      redirect_to person_path(existing), notice: "#{other.display_label} is already in your People."
    else
      person = current_user.people.create!(
        name:     other.display_label,
        email:    other.email,
        timezone: other.timezone
      )
      redirect_to person_path(person), notice: "Added #{other.display_label} to your People."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to matches_path, alert: "Couldn't add to People: #{e.record.errors.full_messages.to_sentence}."
  end
end
