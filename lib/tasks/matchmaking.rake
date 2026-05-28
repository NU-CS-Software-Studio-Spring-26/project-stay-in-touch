namespace :matchmaking do
  desc "Run one AI matchmaking round for all opted-in users"
  task run: :environment do
    # perform_now so an external scheduler (Heroku Scheduler / GitHub Actions) runs
    # the work to completion before the process exits. With the :async queue adapter
    # perform_later would enqueue into a process that immediately exits and lose it.
    RunMatchmakingJob.perform_now
  end
end
