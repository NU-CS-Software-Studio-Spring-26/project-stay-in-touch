class ExpireSchedulingNegotiationsJob < ApplicationJob
  queue_as :default

  def perform
    SchedulingNegotiation.pending.where("expires_at < ?", Time.current).find_each do |negotiation|
      negotiation.expired!
      negotiation.parties.each do |party|
        SchedulingMailer.expired(negotiation, party).deliver_later
      end
    rescue StandardError => e
      Rails.logger.warn("ExpireSchedulingNegotiationsJob: negotiation #{negotiation.id}: #{e.message}")
    end
  end
end
