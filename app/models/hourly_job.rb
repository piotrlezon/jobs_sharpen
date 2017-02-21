class HourlyJob < ApplicationRecord
  MAX_ALLOWED_FAILURES = 3
  MAX_NUMBER_OF_JOBS_RUNNING = 5

  enum status: [:initial, :completed, :failed, :aborted, :running]

  scope :to_run, -> { where(status: statuses.values_at(:initial, :failed)).order(:time) }

  def self.create_new_jobs
    where(time: Time.zone.now.beginning_of_hour).first_or_create
  end

  def self.run
    while (hourly_jobs = to_run).present?
      hourly_jobs.each do |hourly_job|
        hourly_job.run_exclusively if can_run_more_jobs?
      end
    end
  end

  def self.can_run_more_jobs?
    running.count < MAX_NUMBER_OF_JOBS_RUNNING
  end

  def run_exclusively
    with_lock do
      return unless initial?
      # TODO - running! vs run
      running!
    end
    run
  end

  def run
    run!
    completed!
  rescue
    update!(failure_count: failure_count + 1, status: status_when_failed)
  rescue Exception
    failed!
    raise
  end

  private

  def run!; end

  def status_when_failed
    failure_count >= MAX_ALLOWED_FAILURES ? :aborted : :failed
  end
end
