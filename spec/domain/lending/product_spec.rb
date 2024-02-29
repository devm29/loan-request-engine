# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lending::Product do
  def definition(**overrides)
    {
      'name' => 'Fix & Flip', 'description' => 'Buy, rehab, resell',
      'purchase_price_ltv' => '0.90', 'arv_ltv' => '0.70',
      'annual_interest_rate' => '0.13',
      'min_term_months' => 1, 'max_term_months' => 12
    }.merge(overrides.transform_keys(&:to_s))
  end

  it 'reads every rate as an exact decimal' do
    product = described_class.new('fix_and_flip', definition)

    expect(product.purchase_price_ltv).to eq(BigDecimal('0.90'))
    expect(product.arv_ltv).to eq(BigDecimal('0.70'))
    expect(product.annual_interest_rate).to eq(BigDecimal('0.13'))
    expect(product.annual_interest_rate).to be_a(BigDecimal)
  end

  it 'is frozen, so a quote cannot mutate the policy it was priced against' do
    expect(described_class.new('fix_and_flip', definition)).to be_frozen
  end

  # An unquoted 0.13 in YAML is parsed by Psych as a binary Float. Absorbing it
  # silently is how the original defect entered the application.
  it 'refuses a rate that YAML handed it as a Float' do
    expect { described_class.new('bad', definition(annual_interest_rate: 0.13)) }
      .to raise_error(described_class::InvalidDefinition, /Float/)
  end

  it 'refuses a rate outside nought to one' do
    expect { described_class.new('bad', definition(arv_ltv: '1.4')) }
      .to raise_error(described_class::InvalidDefinition, /outside 0\.\.1/)
  end

  it 'refuses a definition missing a required key' do
    expect { described_class.new('bad', definition.except('arv_ltv')) }
      .to raise_error(described_class::InvalidDefinition, /arv_ltv/)
  end

  it 'refuses an impossible term range' do
    expect { described_class.new('bad', definition(min_term_months: 12, max_term_months: 6)) }
      .to raise_error(described_class::InvalidDefinition, /term range/)
  end

  describe '#term_months_valid?' do
    subject(:product) { described_class.new('fix_and_flip', definition(min_term_months: 3, max_term_months: 9)) }

    it { expect(product.term_months_valid?(3)).to be(true) }
    it { expect(product.term_months_valid?(9)).to be(true) }
    it { expect(product.term_months_valid?(2)).to be(false) }
    it { expect(product.term_months_valid?(10)).to be(false) }
    it { expect(product.term_months_valid?(nil)).to be(false) }
    it { expect(product.term_months_valid?('6')).to be(false) }
  end
end
