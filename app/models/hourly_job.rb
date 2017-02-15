class HourlyJob < ApplicationRecord
  enum status: [:initial, :completed]

  def run
    completed!
  end
end
