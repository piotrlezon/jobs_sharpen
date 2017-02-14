class CreateHourlyJobs < ActiveRecord::Migration[5.0]
  def change
    create_table :hourly_jobs do |t|
      t.integer :status, limit: 1, null: false, unsigned: true, default: 0
      t.integer :failure_count, limit: 1, null: false, unsigned: true, default: 0
      t.datetime :time, null: false
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps

      t.index [:time], unique: true
    end
  end
end
