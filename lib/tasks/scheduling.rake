namespace :scheduling do
  desc "Expire scheduling negotiations whose 48-hour window has passed"
  task expire: :environment do
    ExpireSchedulingNegotiationsJob.perform_now
  end
end
