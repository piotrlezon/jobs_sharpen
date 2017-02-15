FactoryGirl.define do
  factory :hourly_job do
    time Time.zone.now.beginning_of_hour
  end
end
