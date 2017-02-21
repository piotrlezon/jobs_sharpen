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
      it 'changes status to failed' do
        expect { run_hourly_job }.not_to raise_error
        expect(hourly_job.reload.failed?).to be(true)
      end

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

    context 'when the process gets terminated' do
      before { expect(hourly_job).to receive(:run!).and_raise(SignalException, 'SIGTERM') }

      it 'changes status to failed' do
        expect { run_hourly_job }.to raise_error(SignalException, 'SIGTERM')
        expect(hourly_job.reload.failed?).to be(true)
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

    it 'runs exclusively all jobs to run', :aggregate_failures do
      # TODO - is it really an elegant spec?
      run_hourly_jobs
    end

    context 'when a new job is created while previous jobs are running' do
      let(:new_hourly_job_to_run) { create(:hourly_job) }
      let(:to_run_responses) { [hourly_jobs, [new_hourly_job_to_run], []] }

      it 'runs the new job as well' do
        expect(new_hourly_job_to_run).to receive(:run_exclusively)
        run_hourly_jobs
      end
    end

    context 'when the first job keeps failing' do
      let(:to_run_responses) { [hourly_jobs, []] }

      before { expect(hourly_jobs.first).to receive(:run!).and_raise('job failed') }

      it 'runs the remaining jobs anyway' do
        expect(hourly_jobs.last).to receive(:run_exclusively)
        run_hourly_jobs
      end
    end
  end
end
