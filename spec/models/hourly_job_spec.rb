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
    end

    context 'when the process gets terminated' do
      before { expect(hourly_job).to receive(:run!).and_raise(SignalException, 'SIGTERM') }

      it 'changes status to failed' do
        expect { run_hourly_job }.to raise_error(SignalException, 'SIGTERM')
        expect(hourly_job.reload.failed?).to be(true)
      end
    end
  end
end
