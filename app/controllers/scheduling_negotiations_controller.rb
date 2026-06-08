class SchedulingNegotiationsController < ApplicationController
  before_action :set_negotiation

  def show
  end

  def confirm
    slot = @negotiation.scheduling_slots.find_by(id: params[:slot_id])
    return redirect_to scheduling_negotiation_path(@negotiation), alert: "Slot not found." unless slot

    SchedulingNegotiation.transaction do
      @negotiation.lock!
      if !@negotiation.pending?
        redirect_to scheduling_negotiation_path(@negotiation), alert: "This meeting has already been resolved." and return
      end
      if @negotiation.past_expiry?
        redirect_to scheduling_negotiation_path(@negotiation), alert: "The scheduling window has expired." and return
      end

      slot.update!(confirmed_by: current_user)
      @negotiation.confirmed!
      @negotiation.meeting_proposal.update!(meeting_at: slot.starts_at)
    end

    book_calendar_event(slot)

    @negotiation.parties.each { |p| SchedulingMailer.confirmed(@negotiation, p).deliver_later }
    broadcast_proposal_update

    redirect_to scheduling_negotiation_path(@negotiation), notice: "Meeting confirmed!"
  end

  private

  def set_negotiation
    @negotiation = SchedulingNegotiation
      .includes(:scheduling_slots, meeting_proposal: [ :requester, :recipient ])
      .find(params[:id])
    unless @negotiation.parties.include?(current_user)
      redirect_to matches_path, alert: "Not authorized." and return
    end
  end

  def book_calendar_event(slot)
    proposal = @negotiation.meeting_proposal
    host     = proposal.requester.google_calendar_connected? ? proposal.requester : proposal.recipient
    return unless host&.google_calendar_connected?

    guest   = proposal.other_party(host)
    service = GoogleCalendarService.new(host)
    event   = service.push_user_meeting(
      summary:          "Intro: #{proposal.requester.display_label} & #{proposal.recipient.display_label}",
      description:      proposal.pitch,
      start_time:       slot.starts_at,
      duration_minutes: SchedulingSlot::DURATION_MINUTES,
      attendee_emails:  [ guest.email ],
      tz_name:          host.timezone
    )
    proposal.update!(
      calendar_event_id:   event.id,
      calendar_event_link: event.html_link,
      calendar_created:    true
    )
  rescue StandardError => e
    Rails.logger.warn("SchedulingNegotiationsController#book_calendar_event: #{e.message}")
  end

  def broadcast_proposal_update
    proposal = @negotiation.meeting_proposal.reload
    @negotiation.parties.each do |party|
      Turbo::StreamsChannel.broadcast_update_to(
        [ party, :matches ],
        target:  dom_id(proposal),
        partial: "meeting_proposals/proposal",
        locals:  { proposal: proposal, current_user: party }
      )
    end
  end
end
