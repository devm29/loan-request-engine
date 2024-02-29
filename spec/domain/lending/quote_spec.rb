# frozen_string_literal: true

require 'rails_helper'

# The arithmetic specification of the whole application.
#
# Every expectation here is pinned to the cent. If a refactor changes one of
# these numbers it has changed what a borrower is asked to sign, and that is a
# defect regardless of how much tidier the code reads.
RSpec.describe Lending::Quote do
  let(:product) { product_with } # 90% LTC, 70% LTV, 13% a year, 1-12 months

  describe 'the policy caps' do
    subject(:quote) { build_quote(product: product, purchase_price: 215_000, repair_budget: 48_000, arv: 340_000) }

    it 'caps the purchase price at the loan-to-cost ratio' do
      expect(quote.purchase_price_cap).to eq(BigDecimal('193500')) # 215,000 x 0.90
    end

    it 'caps the after-repair value at the loan-to-value ratio' do
      expect(quote.arv_cap).to eq(BigDecimal('238000')) # 340,000 x 0.70
    end

    it 'funds the lower of the two caps' do
      expect(quote.max_fundable_amount).to eq(BigDecimal('193500'))
    end

    it 'names which cap bound the loan' do
      expect(quote.binding_constraint).to eq(:purchase_price)
    end

    it 'returns every figure as a BigDecimal, never a Float' do
      %i[purchase_price_cap arv_cap max_fundable_amount interest_expense
         total_repayment cash_required total_project_cost estimated_profit].each do |figure|
        expect(quote.public_send(figure)).to be_a(BigDecimal), "#{figure} was a #{quote.public_send(figure).class}"
      end
    end
  end

  describe 'which cap binds' do
    it 'reports the ARV cap when the exit valuation is the limit' do
      quote = build_quote(product: product, purchase_price: 300_000, arv: 300_000)
      expect(quote.binding_constraint).to eq(:arv)
      expect(quote.max_fundable_amount).to eq(BigDecimal('210000'))
    end

    it 'reports :both when the two caps coincide exactly' do
      # 0.90 x 210,000 == 0.70 x 270,000 == 189,000
      quote = build_quote(product: product, purchase_price: 210_000, arv: 270_000)
      expect(quote.binding_constraint).to eq(:both)
    end
  end

  describe 'rounding policy' do
    # 300_000 * 0.7 is 210000.00000000003 in binary floating point: both wrong
    # to the cent and above the policy cap it claims to be.
    it 'never produces an amount above the cap it was derived from' do
      [123_457, 100_013, 999_999, 7, 333_333].each do |amount|
        quote = build_quote(product: product, purchase_price: amount, arv: amount)

        expect(quote.max_fundable_amount).to be <= BigDecimal(amount) * BigDecimal('0.9')
        expect(quote.max_fundable_amount).to be <= BigDecimal(amount) * BigDecimal('0.7')
      end
    end

    it 'truncates a cap rather than rounding it up' do
      # 123,457 x 0.70 = 86,419.90 exactly; 123,457 x 0.90 = 111,111.30
      quote = build_quote(product: product, purchase_price: 123_457, arv: 123_457)
      expect(quote.arv_cap).to eq(BigDecimal('86419.9'))
      expect(quote.max_fundable_amount).to eq(BigDecimal('86419.9'))
    end

    it 'floors, rather than rounds, a cap whose third decimal would round up' do
      # 101 x 0.6667 = 67.3367. Rounding gives 67.34, which is above the cap;
      # flooring gives 67.33, which is not.
      quote = build_quote(product: product_with(arv_ltv: '0.6667'), purchase_price: 1_000_000, arv: 101)

      expect(quote.arv_cap).to eq(BigDecimal('67.33'))
      expect(quote.arv_cap).to be < BigDecimal('101') * BigDecimal('0.6667')
    end

    it 'rounds the interest charge half-up to the nearest cent' do
      # 1,000 x 0.13 x 1 / 12 = 10.8333...
      expect(described_class.interest_expense(amount: 1_000, annual_rate: BigDecimal('0.13'), term_months: 1))
        .to eq(BigDecimal('10.83'))
    end

    it 'keeps interest to two decimal places' do
      interest = described_class.interest_expense(amount: 1_000, annual_rate: BigDecimal('0.13'), term_months: 1)
      expect(interest.to_s('F').split('.').last.length).to be <= 2
    end
  end

  describe 'interest' do
    # Regression, and the reason this object exists. Computing the monthly rate
    # first - amount x (0.13 / 12) x 6 - materialises a non-terminating decimal
    # and then rounds it again, which returned 6,500.84 where 6,500.85 is owed.
    it 'does not lose a cent on the known rounding boundary' do
      expect(described_class.interest_expense(amount: 100_013, annual_rate: BigDecimal('0.13'), term_months: 6))
        .to eq(BigDecimal('6500.85'))
    end

    it 'is not what the naive monthly-rate-first expression produces' do
      naive = (BigDecimal('100013') * (BigDecimal('0.13') / 12) * 6).round(2)
      correct = described_class.interest_expense(amount: 100_013, annual_rate: BigDecimal('0.13'), term_months: 6)

      expect(naive).to eq(BigDecimal('6500.84'))
      expect(correct).to eq(BigDecimal('6500.85'))
      expect(correct - naive).to eq(BigDecimal('0.01'))
    end

    it 'charges a full year of interest over twelve months' do
      expect(described_class.interest_expense(amount: 100_000, annual_rate: BigDecimal('0.13'), term_months: 12))
        .to eq(BigDecimal('13000'))
    end

    it 'charges half a year of interest over six months' do
      expect(described_class.interest_expense(amount: 210_000, annual_rate: BigDecimal('0.13'), term_months: 6))
        .to eq(BigDecimal('13650'))
    end

    it 'charges nothing over a zero-month term' do
      expect(described_class.interest_expense(amount: 100_000, annual_rate: BigDecimal('0.13'), term_months: 0))
        .to eq(BigDecimal('0'))
    end

    it 'scales linearly in the term, to the cent, across the product window' do
      one_month = described_class.interest_expense(amount: 120_000, annual_rate: BigDecimal('0.13'), term_months: 1)
      twelve = described_class.interest_expense(amount: 120_000, annual_rate: BigDecimal('0.13'), term_months: 12)

      expect(one_month).to eq(BigDecimal('1300'))
      expect(twelve).to eq(one_month * 12)
    end

    it 'charges interest on the funded amount, not the project cost' do
      quote = build_quote(product: product, purchase_price: 215_000, repair_budget: 48_000, arv: 340_000)
      expect(quote.interest_expense)
        .to eq(described_class.interest_expense(amount: quote.max_fundable_amount,
                                                annual_rate: product.annual_interest_rate, term_months: 6))
    end
  end

  describe 'the borrower-facing totals' do
    subject(:quote) { build_quote(product: product, purchase_price: 215_000, repair_budget: 48_000, arv: 340_000) }

    # 193,500 funded; interest 193,500 x 0.13 x 6/12 = 12,577.50
    it 'adds interest to the principal for the exit repayment' do
      expect(quote.interest_expense).to eq(BigDecimal('12577.5'))
      expect(quote.total_repayment).to eq(BigDecimal('206077.5'))
    end

    it 'asks the borrower for the project cost we do not fund' do
      expect(quote.total_project_cost).to eq(BigDecimal('263000'))
      expect(quote.cash_required).to eq(BigDecimal('69500'))
    end

    it 'estimates profit as the exit value less the loan and its interest' do
      expect(quote.estimated_profit).to eq(BigDecimal('133922.5'))
    end

    it 'never asks the borrower for a negative amount of cash' do
      # The purchase-price cap is at most 100% of the purchase price and the
      # project also carries the repair budget, so cash_required >= repairs.
      [[1, 1, 1], [500_000, 1, 10_000_000], [100, 250_000, 900_000]].each do |price, repairs, arv|
        quote = build_quote(product: product, purchase_price: price, repair_budget: repairs, arv: arv)
        expect(quote.cash_required).to be >= 0
      end
    end
  end

  describe 'the term window' do
    it 'accepts a term inside the product range' do
      expect(build_quote(product: product, term_months: 6)).to be_term_within_product_range
    end

    it 'rejects a term past the product maximum' do
      expect(build_quote(product: product, term_months: 24)).not_to be_term_within_product_range
    end
  end

  describe 'input handling' do
    it 'accepts integers, decimal strings and BigDecimals interchangeably' do
      from_integer = build_quote(product: product, purchase_price: 215_000)
      from_string = build_quote(product: product, purchase_price: '215000')
      from_decimal = build_quote(product: product, purchase_price: BigDecimal('215000'))

      expect(from_string.max_fundable_amount).to eq(from_integer.max_fundable_amount)
      expect(from_decimal.max_fundable_amount).to eq(from_integer.max_fundable_amount)
    end

    it 'refuses a Float rather than quietly absorbing its error' do
      expect { build_quote(product: product, purchase_price: 215_000.0) }
        .to raise_error(Lending::Money::FloatError, /refusing to build money from the Float/)
    end

    it 'refuses a non-integer term' do
      expect { build_quote(product: product, term_months: 'six') }.to raise_error(ArgumentError)
    end
  end

  describe 'different products' do
    it 'prices the same deal differently under a different product' do
      bridge = product_with(purchase_price_ltv: '0.80', arv_ltv: '0.65', annual_interest_rate: '0.1150')
      quote = build_quote(product: bridge, purchase_price: 410_000, repair_budget: 22_000,
                          arv: 615_000, term_months: 9)

      expect(quote.purchase_price_cap).to eq(BigDecimal('328000'))  # 410,000 x 0.80
      expect(quote.arv_cap).to eq(BigDecimal('399750'))             # 615,000 x 0.65
      expect(quote.max_fundable_amount).to eq(BigDecimal('328000'))
      expect(quote.interest_expense).to eq(BigDecimal('28290'))     # 328,000 x 0.1150 x 9/12
    end

    it 'prices every catalogued product without raising' do
      Lending::Catalog.all.each do |catalogued|
        quote = build_quote(product: catalogued, term_months: catalogued.min_term_months)
        expect(quote.to_h[:max_fundable_amount]).to be_a(BigDecimal)
      end
    end
  end

  describe '#to_h' do
    it 'exposes every figure the term sheet prints' do
      expect(build_quote(product: product).to_h.keys).to include(
        :product_code, :term_months, :purchase_price, :repair_budget, :arv,
        :total_project_cost, :purchase_price_cap, :arv_cap, :max_fundable_amount,
        :binding_constraint, :interest_expense, :total_repayment, :cash_required, :estimated_profit
      )
    end
  end
end
