namespace :nudges do
  desc "Send push notifications for overdue contacts and upcoming birthdays"
  task push: :environment do
    NudgeNotificationJob.perform_now
  end
end
