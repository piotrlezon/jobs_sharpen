class HourlyJob < ApplicationRecord
  enum status: [:initial, :completed, :failed]

  def run
    run!
    completed!
  rescue
    failed!
  end

  private

  def run!; end
end
