class HourlyJob < ApplicationRecord
  MAX_ALLOWED_FAILURES = 3

  enum status: [:initial, :completed, :failed, :aborted]

  def run
    run!
    completed!
  rescue
    update!(failure_count: failure_count + 1, status: status_when_failed)
  end

  private

  def run!; end

  def status_when_failed
    failure_count >= MAX_ALLOWED_FAILURES ? :aborted : :failed
  end
end
