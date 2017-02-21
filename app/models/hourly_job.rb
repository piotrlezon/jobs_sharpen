class HourlyJob < ApplicationRecord
  MAX_ALLOWED_FAILURES = 3

  enum status: [:initial, :completed, :failed, :aborted, :running]

  scope :to_run, -> { where(status: statuses.values_at(:initial, :failed)).order(:time) }

  def self.run
    while (hourly_jobs = to_run).present?
      hourly_jobs.each(&:run_exclusively)
    end
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
