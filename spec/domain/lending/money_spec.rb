# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lending::Money do
  describe '.cast' do
    it 'accepts an Integer' do
      expect(described_class.cast(100)).to eq(BigDecimal('100'))
    end

    it 'accepts a decimal String exactly' do
      expect(described_class.cast('0.13')).to eq(BigDecimal('0.13'))
    end

    it 'returns a BigDecimal unchanged' do
      value = BigDecimal('1.23')
      expect(described_class.cast(value)).to equal(value)
    end

    it 'accepts a Rational' do
      expect(described_class.cast(Rational(1, 4))).to eq(BigDecimal('0.25'))
    end

    # The defect this module exists to prevent: 0.13 has no exact binary
    # representation, so a Float rate contaminates every figure downstream.
    it 'refuses a Float, naming it, rather than converting it' do
      expect { described_class.cast(0.13) }
        .to raise_error(described_class::FloatError, /0\.13/)
    end

    it 'refuses nil' do
      expect { described_class.cast(nil) }.to raise_error(ArgumentError, /nil/)
    end

    it 'refuses a type it has no exact reading of' do
      expect { described_class.cast(Object.new) }.to raise_error(ArgumentError, /cannot build money/)
    end
  end

  describe '.round_to_cent' do
    it 'rounds half up' do
      expect(described_class.round_to_cent('10.835')).to eq(BigDecimal('10.84'))
    end

    it 'rounds down below the half cent' do
      expect(described_class.round_to_cent('10.834')).to eq(BigDecimal('10.83'))
    end

    it 'leaves an exact cent alone' do
      expect(described_class.round_to_cent('10.83')).to eq(BigDecimal('10.83'))
    end
  end

  describe '.floor_to_cent' do
    it 'truncates rather than rounding' do
      expect(described_class.floor_to_cent('10.839')).to eq(BigDecimal('10.83'))
    end

    it 'never returns more than it was given' do
      %w[10.839 0.999 210000.00000000003 86419.90000001].each do |value|
        expect(described_class.floor_to_cent(value)).to be <= BigDecimal(value)
      end
    end

    # Caps are non-negative, so this only pins the direction: down, never up.
    it 'rounds a negative value down rather than towards zero' do
      expect(described_class.floor_to_cent('-10.839')).to eq(BigDecimal('-10.84'))
    end
  end

  it 'differs from rounding exactly where it matters' do
    expect(described_class.round_to_cent('99.999')).to eq(BigDecimal('100'))
    expect(described_class.floor_to_cent('99.999')).to eq(BigDecimal('99.99'))
  end
end
