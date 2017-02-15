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
end
