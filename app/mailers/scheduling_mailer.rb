class SchedulingMailer < ApplicationMailer
  def invite(negotiation, recipient)
    @negotiation = negotiation
    @recipient   = recipient
    @proposal    = negotiation.meeting_proposal
    @other       = @proposal.other_party(recipient)
    @url         = scheduling_negotiation_url(negotiation)
    @expires_at  = negotiation.expires_at
    mail(to: recipient.email, subject: "Choose a time to meet #{@other&.display_label}")
  end

  def confirmed(negotiation, recipient)
    @negotiation = negotiation
    @recipient   = recipient
    @proposal    = negotiation.meeting_proposal
    @other       = @proposal.other_party(recipient)
    @slot        = negotiation.confirmed_slot
    mail(to: recipient.email, subject: "Meeting confirmed with #{@other&.display_label}")
  end

  def expired(negotiation, recipient)
    @negotiation = negotiation
    @recipient   = recipient
    @proposal    = negotiation.meeting_proposal
    @other       = @proposal.other_party(recipient)
    mail(to: recipient.email, subject: "Scheduling window expired")
  end
end
