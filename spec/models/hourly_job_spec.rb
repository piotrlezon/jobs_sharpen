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
  end
end
