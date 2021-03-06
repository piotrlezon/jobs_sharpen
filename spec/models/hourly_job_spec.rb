require 'rails_helper'

RSpec.describe HourlyJob do
  describe '.create' do
    subject { create(:hourly_job) }

    it 'sets new job\'s status to initial' do
      # TODO - expect(subject.initial?).to be_true is simpler but would give poor error message
      expect(subject.status).to eq('initial')
    end
  end

  describe '#run' do
    let(:hourly_job) { create(:hourly_job) }

    subject(:run_hourly_job) { hourly_job.run }

    context 'when the job succeeds' do
      it 'changes status to completed' do
        run_hourly_job
        expect(hourly_job.reload.completed?).to be(true)
      end
    end

    context 'when the job fails' do
      before { expect(hourly_job).to receive(:run!).and_raise('job failed') }

      it 'increments failure counter' do
        expect { run_hourly_job }.to change { hourly_job.failure_count }.by(1)
      end

      context 'for the first time' do
        it 'changes status to failed' do
          run_hourly_job
          expect(hourly_job.reload.failed?).to be(true)
        end
      end

      context 'for the last allowed time' do
        before { hourly_job.failure_count = described_class::MAX_ALLOWED_FAILURES + 1 }

        it 'changes status to aborted' do
          run_hourly_job
          expect(hourly_job.reload.aborted?).to be(true)
        end
      end
    end
  end

  describe '#run_exclusively' do
    subject(:run_hourly_job_exclusively) { hourly_job.run_exclusively }

    context 'when job is initial' do
      let(:hourly_job) { create(:initial_hourly_job) }

      context 'when called multiple times' do
        before { expect(ActiveRecord::Base.connection.pool.size).to be >= 5 }

        it 'runs job only once', no_transactionial_db_cleaner: true do
          expect(hourly_job).to receive(:run).once.and_call_original
          keep_waiting = true
          threads = (ActiveRecord::Base.connection.pool.size - 1).times.map do
            Thread.new do
              true while keep_waiting
              hourly_job.run_exclusively # TODO subject can be called a single time only
            end
          end
          keep_waiting = false
          threads.each(&:join)
        end
      end

      it 'runs the job' do
        # TODO should this spec test that the run method got called or that the status changed to completed?
        expect(hourly_job).to receive(:run).and_call_original
        run_hourly_job_exclusively
      end
    end

    described_class.statuses.except(:initial).each do |status_name, status_value|
      context "when job is #{status_name}" do
        let(:hourly_job) { create(:hourly_job, status: status_value) }

        it 'does not run the job' do
          expect(hourly_job).not_to receive(:run)
          run_hourly_job_exclusively
        end
      end
    end
  end

  describe '.to_run' do
    let!(:hourly_jobs_not_to_run) do
      described_class.statuses.except(:initial, :failed).values.map { |status| create(:hourly_job, status: status) }
    end

    let!(:hourly_jobs) do
      [create(:initial_hourly_job, time: described_class.maximum(:time) + 1.hour),
       create(:failed_hourly_job, time: described_class.minimum(:time) - 1.hour),
       create(:initial_hourly_job, time: described_class.maximum(:time) + 3.hours),
       create(:failed_hourly_job, time: described_class.maximum(:time) + 4.hours)]
    end

    let(:chronological_hourly_jobs) { hourly_jobs.sort_by(&:time) }

    subject { described_class.to_run }

    it 'returns only initial & failed jobs in chronological order' do
      expect(subject).to eq(chronological_hourly_jobs)
    end

    it 'doesn\'t return any jobs with statuses different than initial or failed' do
      is_expected.not_to include(*hourly_jobs_not_to_run)
    end
  end

  describe '.run' do
    let(:hourly_jobs) do
      Array.new(2) { build(:hourly_job) }
    end

    let(:to_run_responses) { [hourly_jobs, hourly_jobs.drop(1), []] }

    before do
      allow(described_class).to receive(:to_run).and_return(*to_run_responses)
    end

    subject(:run_hourly_jobs) { described_class.run }

    context 'when it can run all the jobs' do
      before do
        allow(described_class).to receive(:can_run_more_jobs?).and_return(true)
      end

      it 'runs all the jobs', :aggregate_failures do
        expect(hourly_jobs.first).to receive(:run!)
        expect(hourly_jobs.second).to receive(:run!)
        run_hourly_jobs
      end

      context 'when a new job is created while previous jobs are running' do
        let(:new_hourly_job_to_run) { create(:hourly_job) }
        let(:to_run_responses) { [hourly_jobs, [new_hourly_job_to_run], []] }

        it 'runs the new job as well' do
          expect(new_hourly_job_to_run).to receive(:run!)
          run_hourly_jobs
        end
      end
    end

    context 'if it can only run one more job' do
      before do
        expect(described_class).to receive(:can_run_more_jobs?).and_return(true, false)
      end

      it 'runs the first job only' do
        expect(hourly_jobs.first).to receive(:run!)
        expect(hourly_jobs.last).not_to receive(:run!)
        run_hourly_jobs
      end
    end

    context 'if it cannot run more jobs' do
      before do
        allow(described_class).to receive(:can_run_more_jobs?).and_return(false)
      end

      it 'does not try to run more jobs' do
        expect(hourly_jobs.first).not_to receive(:run!)
        expect(hourly_jobs.last).not_to receive(:run!)
        run_hourly_jobs
      end
    end
  end

  describe '.can_run_more_jobs?' do
    before do
      Array.new(num_of_jobs_running) { create(:running_hourly_job) }
    end

    subject { described_class.send(:can_run_more_jobs?) }

    context 'when there are max allowed jobs running already' do
      let(:num_of_jobs_running) { described_class::MAX_NUMBER_OF_JOBS_RUNNING }

      it { is_expected.to be(false) }
    end

    context 'when there are less than max allowed jobs already running' do
      let(:num_of_jobs_running) { described_class::MAX_NUMBER_OF_JOBS_RUNNING - 1 }

      it { is_expected.to be(true) }
    end
  end

  describe '.create_new_jobs' do
    let(:now) { Time.zone.now }

    let(:time_to_create_new_jobs_since) { now.beginning_of_hour - 1.hour }
    let(:expected_job_times) do
      [time_to_create_new_jobs_since,
       time_to_create_new_jobs_since + 1.hour]
    end

    before do
      # TODO - we could do it without mocking but the specs would be more complex
      # TODO - allow or expect?
      allow(described_class).to receive(:time_to_create_new_jobs_since).and_return(time_to_create_new_jobs_since)
    end

    subject(:create_new_jobs) do
      Timecop.freeze(now) { described_class.create_new_jobs }
    end

    it 'creates jobs missing since the time_to_create_new_jobs_since' do
      create_new_jobs
      expect(described_class.pluck(:time)).to eq([time_to_create_new_jobs_since,
                                                  time_to_create_new_jobs_since + 1.hour])
    end

    context 'when multiple processes try to create jobs' do
      before { expect(ActiveRecord::Base.connection.pool.size).to be >= 5 }

      it 'creates jobs missing since the time_to_create_new_jobs_since', no_transactionial_db_cleaner: true do
        keep_waiting = true
        threads = Array.new(ActiveRecord::Base.connection.pool.size - 1) do
          Thread.new do
            true while keep_waiting
            Timecop.freeze(now) { described_class.create_new_jobs }
          end
        end
        keep_waiting = false
        threads.each(&:join)
        expect(described_class.pluck(:time)).to eq(expected_job_times)
      end
    end
  end

  describe '.time_to_create_new_jobs_since' do
    let(:now) { Time.zone.now }
    # TODO - this method should be private - should it be tested like that?

    subject do
      Timecop.freeze(now) { described_class.time_to_create_new_jobs_since }
    end

    context 'when no jobs exist yet' do
      it 'returns current hour' do
        is_expected.to eq(now.beginning_of_hour)
      end
    end

    context 'when some job already exists' do
      let!(:previous_job) { create(:hourly_job, time: now.beginning_of_hour - 10.hours) }

      it 'returns the following hour' do
        is_expected.to eq(previous_job.time + 1.hour)
      end
    end
  end
end
