# The "Matches" page: AI-negotiated meeting proposals the current user is party to,
# on either side. The for_user scope is also the authorization boundary — a user can
# only see (and #find) proposals where they are the requester or the recipient.
class MeetingProposalsController < ApplicationController
  def index
    @proposals = MeetingProposal.for_user(current_user)
                                .includes(:requester, :recipient)
                                .recent
  end

  def show
    @proposal = MeetingProposal.for_user(current_user)
                               .includes(:requester, :recipient)
                               .find(params[:id])
  end
end
