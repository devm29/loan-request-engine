# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lending::SubmitLoanRequest do
  let(:attributes) { attributes_for(:loan_request) }

  before { allow(LoanProcessorJob).to receive(:perform_async) }

  describe 'a first submission' do
    it 'creates the request' do
      expect { described_class.call(attributes) }.to change(LoanRequest, :count).by(1)
    end

    it 'reports it as created' do
      result = described_class.call(attributes)

      expect(result).to be_success
      expect(result).not_to be_duplicate
      expect(result.status).to eq(:created)
    end

    it 'enqueues the term sheet job' do
      result = described_class.call(attributes)
      expect(LoanProcessorJob).to have_received(:perform_async).with(result.loan_request.id)
    end

    it 'assigns an unguessable public reference' do
      reference = described_class.call(attributes).loan_request.reference
      expect(reference).to be_present
      expect(reference).not_to match(/\A\d+\z/)
    end
  end

  describe 'a resubmission of the same request' do
    # A double-clicked Submit button, a retried fetch, or a borrower reloading.
    it 'does not create a second record' do
      described_class.call(attributes)
      expect { described_class.call(attributes) }.not_to change(LoanRequest, :count)
    end

    it 'returns the original record' do
      first = described_class.call(attributes).loan_request
      second = described_class.call(attributes)

      expect(second).to be_duplicate
      expect(second).to be_success
      expect(second.loan_request.id).to eq(first.id)
    end

    it 'does not send a second email' do
      described_class.call(attributes)
      described_class.call(attributes)

      expect(LoanProcessorJob).to have_received(:perform_async).once
    end

    it 'treats a differently-cased email as the same request' do
      described_class.call(attributes)
      expect { described_class.call(attributes.merge(email: attributes[:email].upcase)) }
        .not_to change(LoanRequest, :count)
    end
  end

  # The defect the old unique index on email caused: an applicant could use the
  # form exactly once, ever.
  describe 'the same applicant asking about a different property' do
    it 'creates a second request' do
      described_class.call(attributes)

      expect { described_class.call(attributes.merge(address: '88 Sawtooth Ave, Asheville, NC 28801')) }
        .to change(LoanRequest, :count).by(1)
    end

    it 'creates a second request for a different product' do
      described_class.call(attributes)

      expect { described_class.call(attributes.merge(product_code: 'bridge')) }
        .to change(LoanRequest, :count).by(1)
    end
  end

  describe 'an invalid submission' do
    let(:attributes) { attributes_for(:loan_request, email: nil) }

    it 'creates nothing' do
      expect { described_class.call(attributes) }.not_to change(LoanRequest, :count)
    end

    it 'reports failure with the errors attached' do
      result = described_class.call(attributes)

      expect(result).not_to be_success
      expect(result.status).to eq(:invalid)
      expect(result.loan_request.errors[:email]).to be_present
    end

    it 'enqueues nothing' do
      described_class.call(attributes)
      expect(LoanProcessorJob).not_to have_received(:perform_async)
    end
  end

  # The borrower's data is already committed by this point. A Redis outage must
  # not turn a successful submission into a 500 and lose it.
  describe 'when the queue is unreachable' do
    before { allow(LoanProcessorJob).to receive(:perform_async).and_raise(Errno::ECONNREFUSED) }

    it 'still saves the request' do
      expect { described_class.call(attributes) }.to change(LoanRequest, :count).by(1)
    end

    it 'still reports success' do
      expect(described_class.call(attributes)).to be_success
    end

    it 'logs enough to find the undelivered request later' do
      allow(Rails.logger).to receive(:error)
      described_class.call(attributes)

      expect(Rails.logger).to have_received(:error).with(/could not enqueue LoanProcessorJob/)
    end

    it 'leaves it where the requeue task will find it' do
      described_class.call(attributes)
      expect(LoanRequest.undelivered.count).to eq(1)
    end
  end

  describe 'when two identical submissions race' do
    it 'resolves the loser to the winner rather than raising' do
      first = described_class.call(attributes).loan_request

      # The read-before-write loses the race and the unique index fires; the
      # second look-up is the one that finds the winner.
      service = described_class.new(attributes)
      allow(service).to receive(:existing_for).and_return(nil, first)
      allow_any_instance_of(LoanRequest).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)

      result = service.call

      expect(result).to be_duplicate
      expect(result.loan_request.id).to eq(first.id)
    end

    it 're-raises when the index fired for some other reason' do
      service = described_class.new(attributes)
      allow(service).to receive(:existing_for).and_return(nil, nil)
      allow_any_instance_of(LoanRequest).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)

      expect { service.call }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
