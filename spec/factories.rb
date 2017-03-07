FactoryGirl.define do
  factory :hourly_job do
    sequence :time do |index|
      Time.zone.now.beginning_of_hour - index.hours
    end

    factory :initial_hourly_job do
      status HourlyJob.statuses[:initial]
    end

    factory :failed_hourly_job do
      status HourlyJob.statuses[:failed]
    end

    factory :running_hourly_job do
      status HourlyJob.statuses[:running]
    end
  end
end
