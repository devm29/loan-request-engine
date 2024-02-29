# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lending::RequestFingerprint do
  def fingerprint(**overrides)
    described_class.for(
      email: 'dana@ridgelinehomes.co', address: '1420 Chestnut Ridge Rd, Durham, NC',
      product_code: 'fix_and_flip', loan_term: 6, purchase_price: 215_000,
      repair_budget: 48_000, arv: 340_000, **overrides
    )
  end

  it 'is stable for identical input' do
    first = fingerprint
    expect(fingerprint).to eq(first)
  end

  it 'ignores case and surrounding whitespace in the email' do
    expect(fingerprint(email: '  Dana@RidgelineHomes.CO ')).to eq(fingerprint)
  end

  it 'ignores repeated whitespace in the address' do
    expect(fingerprint(address: '1420  Chestnut   Ridge Rd, Durham, NC')).to eq(fingerprint)
  end

  # The same applicant asking about a second property is a different request,
  # which is what the old unique index on email got wrong.
  it 'differs for a different property' do
    expect(fingerprint(address: '88 Sawtooth Ave, Asheville, NC')).not_to eq(fingerprint)
  end

  it 'differs for a different product' do
    expect(fingerprint(product_code: 'bridge')).not_to eq(fingerprint)
  end

  it 'differs for a different term' do
    expect(fingerprint(loan_term: 9)).not_to eq(fingerprint)
  end

  it 'differs for a different figure' do
    expect(fingerprint(arv: 340_001)).not_to eq(fingerprint)
  end

  it 'is a hex digest, so it fits a string column and indexes evenly' do
    expect(fingerprint).to match(/\A[0-9a-f]{64}\z/)
  end
end
