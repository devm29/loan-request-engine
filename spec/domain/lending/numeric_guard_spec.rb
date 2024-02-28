# frozen_string_literal: true

require 'rails_helper'

# The guarantee that a language model can never state a figure to a borrower.
RSpec.describe Lending::NumericGuard do
  let(:facts) { ['$193,500.00', '$12,577.50', '90%', '11.5%', '6 months'] }

  describe '.verify' do
    it 'accepts prose with no figures at all' do
      expect(described_class.verify('The purchase price is what limits this loan.', facts: facts)).to be(true)
    end

    it 'accepts a figure the lending code computed' do
      expect(described_class.verify('We can fund $193,500.00 here.', facts: facts)).to be(true)
    end

    it 'accepts the same amount written without its trailing zeros' do
      expect(described_class.verify('We can fund $193,500 here.', facts: facts)).to be(true)
    end

    it 'rejects a figure that is merely close' do
      expect(described_class.verify('We can fund $193,501.00 here.', facts: facts)).to be(false)
    end

    it 'rejects an invented figure entirely' do
      expect(described_class.verify('You could borrow up to $400,000.', facts: facts)).to be(false)
    end

    it 'rejects a plausible but uncomputed percentage' do
      expect(described_class.verify('We lend at 75% of value.', facts: facts)).to be(false)
    end

    # "$70" and "70%" are different claims; neither vouches for the other.
    it 'treats a unit as part of the figure' do
      expect(described_class.verify('That is 90% of it.', facts: ['$90.00'])).to be(false)
      expect(described_class.verify('That is $90.00.', facts: ['90%'])).to be(false)
    end

    it 'accepts a bare number that appears in a fact' do
      expect(described_class.verify('Over 6 months.', facts: facts)).to be(true)
    end

    it 'rejects a bare number that does not' do
      expect(described_class.verify('Over 9 months.', facts: facts)).to be(false)
    end
  end

  describe '.unvouched_tokens' do
    it 'reports exactly what it objected to' do
      text = 'We can fund $193,500.00 at 14% over 6 months.'
      expect(described_class.unvouched_tokens(text, facts: facts)).to eq(['14%'])
    end

    it 'reports nothing for clean prose' do
      expect(described_class.unvouched_tokens('No figures here.', facts: facts)).to be_empty
    end

    it 'treats an empty fact list as vouching for nothing' do
      expect(described_class.unvouched_tokens('$1', facts: [])).to eq(['$1'])
    end

    it 'handles nil text' do
      expect(described_class.unvouched_tokens(nil, facts: facts)).to be_empty
    end
  end
end
