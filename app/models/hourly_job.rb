class HourlyJob < ApplicationRecord
  enum status: [:initial, :completed, :failed]

  def run
    run!
    completed!
  rescue
    failed!
  rescue Exception
    failed!
    raise
  end

  private

  def run!; end
end
