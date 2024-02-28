# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lending::Format do
  describe '.currency' do
    it 'renders whole amounts with two decimal places and thousands separators' do
      expect(described_class.currency(193_500)).to eq('$193,500.00')
    end

    it 'renders cents' do
      expect(described_class.currency(BigDecimal('6500.85'))).to eq('$6,500.85')
    end

    it 'pads a single decimal place' do
      expect(described_class.currency(BigDecimal('12577.5'))).to eq('$12,577.50')
    end

    it 'renders amounts below a thousand without a separator' do
      expect(described_class.currency(7)).to eq('$7.00')
    end

    it 'renders zero' do
      expect(described_class.currency(0)).to eq('$0.00')
    end

    it 'puts the sign before the symbol for a negative amount' do
      expect(described_class.currency(BigDecimal('-250.5'))).to eq('-$250.50')
    end

    it 'truncates nothing it was not asked to: it rounds to the cent' do
      expect(described_class.currency(BigDecimal('10.835'))).to eq('$10.84')
    end

    it 'separates millions correctly' do
      expect(described_class.currency(1_234_567)).to eq('$1,234,567.00')
    end
  end

  describe '.percent' do
    it 'renders a whole percentage without decimals' do
      expect(described_class.percent(BigDecimal('0.90'))).to eq('90%')
    end

    it 'keeps a fractional percentage' do
      expect(described_class.percent(BigDecimal('0.1150'))).to eq('11.5%')
    end

    it 'keeps two fractional digits when they are significant' do
      expect(described_class.percent(BigDecimal('0.1175'))).to eq('11.75%')
    end

    it 'renders zero' do
      expect(described_class.percent(0)).to eq('0%')
    end
  end

  describe '.months' do
    it 'pluralises' do
      expect(described_class.months(6)).to eq('6 months')
    end

    it 'does not pluralise one' do
      expect(described_class.months(1)).to eq('1 month')
    end
  end
end
