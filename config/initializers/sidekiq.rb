schedule_file = "config/schedule.yml"
Sidekiq.strict_args!(false)

if File.exists?(schedule_file) && Sidekiq.server?
  Sidekiq::Cron::Job.load_from_hash! YAML.load_file(schedule_file)
end
