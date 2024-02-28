# frozen_string_literal: true

require 'rails_helper'

# The model is a persistence and validation boundary. The arithmetic it
# delegates to is specified in spec/domain/lending/quote_spec.rb; what is
# pinned here is that the delegation is wired to the right product and that the
# figures reaching the record are exact.
RSpec.describe LoanRequest, type: :model do
  describe 'validation' do
    it 'accepts a complete request' do
      expect(build(:loan_request)).to be_valid
    end

    it 'requires every field the term sheet depends on' do
      loan_request = described_class.new

      expect(loan_request).not_to be_valid
      %i[address loan_term purchase_price repair_budget arv first_name email phone].each do |field|
        expect(loan_request.errors[field]).to include("can't be blank"), "#{field} was not required"
      end
    end

    it 'does not require a last name' do
      expect(build(:loan_request, last_name: nil)).to be_valid
    end

    it 'requires positive money figures' do
      loan_request = build(:loan_request, purchase_price: 0, repair_budget: 0, arv: 0)

      expect(loan_request).not_to be_valid
      %i[purchase_price repair_budget arv].each do |field|
        expect(loan_request.errors[field]).to include('must be a positive number')
      end
    end

    it 'requires a well-formed email' do
      expect(build(:loan_request, email: 'not-an-email')).not_to be_valid
    end

    it 'rejects a product we do not offer' do
      loan_request = build(:loan_request, product_code: 'mortgage')

      expect(loan_request).not_to be_valid
      expect(loan_request.errors[:product_code]).to include('is not a product we offer')
    end

    it 'defaults to the catalog default product' do
      expect(build(:loan_request, product_code: nil).tap(&:validate).product_code).to eq('fix_and_flip')
    end

    describe 'the term window' do
      it 'accepts a term inside the chosen product range' do
        expect(build(:loan_request, product_code: 'bridge', loan_term: 24)).to be_valid
      end

      it 'rejects a term past the chosen product maximum' do
        loan_request = build(:loan_request, product_code: 'fix_and_flip', loan_term: 24)

        expect(loan_request).not_to be_valid
        expect(loan_request.errors[:loan_term]).to include('must be between 1 and 12 months')
      end

      it 'rejects a term below the chosen product minimum' do
        loan_request = build(:loan_request, product_code: 'new_construction', loan_term: 3)

        expect(loan_request).not_to be_valid
        expect(loan_request.errors[:loan_term]).to include('must be between 6 and 18 months')
      end

      it 'rejects a zero term' do
        expect(build(:loan_request, loan_term: 0)).not_to be_valid
      end
    end
  end

  describe 'identity' do
    it 'normalises the email before validating' do
      loan_request = build(:loan_request, email: '  Mixed.Case@Example.COM ')
      loan_request.validate

      expect(loan_request.email).to eq('mixed.case@example.com')
    end

    it 'assigns an unguessable reference on create' do
      loan_request = create(:loan_request)

      expect(loan_request.reference).to be_present
      expect(loan_request.to_param).to eq(loan_request.reference)
    end

    it 'never exposes the sequential id as its parameter' do
      expect(create(:loan_request).to_param).not_to eq(create(:loan_request).id.to_s)
    end

    # The old unique index on email allowed an applicant exactly one request,
    # ever. The fingerprint expresses the intent properly.
    it 'lets the same applicant ask about a second property' do
      create(:loan_request, email: 'dana@ridgelinehomes.co', address: '1420 Chestnut Ridge Rd')
      second = build(:loan_request, email: 'dana@ridgelinehomes.co', address: '88 Sawtooth Ave')

      expect(second).to be_valid
    end

    it 'refuses a byte-for-byte resubmission' do
      first = create(:loan_request)
      duplicate = build(:loan_request, first.attributes.slice(*%w[address product_code loan_term purchase_price
                                                                  repair_budget arv first_name last_name email phone])
                                            .symbolize_keys)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:request_fingerprint]).to include('has already been submitted')
    end
  end

  describe '#quote' do
    it 'prices against the product the applicant chose' do
      loan_request = build(:loan_request, product_code: 'bridge', purchase_price: 410_000,
                                          repair_budget: 22_000, arv: 615_000, loan_term: 9)

      expect(loan_request.quote.product.code).to eq('bridge')
      expect(loan_request.quote.max_fundable_amount).to eq(BigDecimal('328000'))
    end

    it 'recomputes when the figures change' do
      loan_request = build(:loan_request, purchase_price: 215_000)
      first = loan_request.quote.max_fundable_amount

      loan_request.purchase_price = 100_000
      expect(loan_request.quote.max_fundable_amount).not_to eq(first)
      expect(loan_request.quote.max_fundable_amount).to eq(BigDecimal('90000'))
    end

    it 'reuses the same quote while the figures do not change' do
      loan_request = build(:loan_request)
      expect(loan_request.quote).to equal(loan_request.quote)
    end
  end

  describe 'money precision' do
    subject(:loan_request) { build(:loan_request, purchase_price: 215_000, repair_budget: 48_000, arv: 340_000) }

    it 'returns the funded amount as an exact decimal' do
      expect(loan_request.calculate_max_fundable_amount).to be_a(BigDecimal)
      expect(loan_request.calculate_max_fundable_amount).to eq(BigDecimal('193500'))
    end

    it 'returns interest as an exact decimal rounded to the cent' do
      interest = loan_request.calculate_interest_expense(BigDecimal('210000'))

      expect(interest).to be_a(BigDecimal)
      expect(interest).to eq(BigDecimal('13650'))
    end

    # Regression: with binary floats this returned 6,500.84.
    it 'does not lose a cent on the known rounding boundary' do
      expect(loan_request.calculate_interest_expense(100_013)).to eq(BigDecimal('6500.85'))
    end

    it 'never funds more than either policy cap allows' do
      loan_request = build(:loan_request, purchase_price: 123_457, arv: 123_457, loan_term: 3)
      amount = loan_request.calculate_max_fundable_amount

      expect(amount).to be <= BigDecimal('123457') * BigDecimal('0.9')
      expect(amount).to be <= BigDecimal('123457') * BigDecimal('0.7')
      expect(amount).to eq(BigDecimal('86419.9'))
    end

    it 'computes profit as the exit value less the loan and its interest' do
      expect(loan_request.calculate_profit).to eq(BigDecimal('133922.5'))
    end
  end

  describe '#full_name' do
    it 'joins first and last name' do
      expect(build(:loan_request, first_name: 'Dana', last_name: 'Whitfield').full_name).to eq('Dana Whitfield')
    end

    it 'does not trail a space when the last name is missing' do
      expect(build(:loan_request, first_name: 'Dana', last_name: nil).full_name).to eq('Dana')
    end

    it 'ignores a blank last name' do
      expect(build(:loan_request, first_name: 'Dana', last_name: '  ').full_name).to eq('Dana')
    end
  end

  describe 'the delivery lifecycle' do
    it 'starts as submitted' do
      expect(create(:loan_request)).to be_submitted
    end

    it 'is not ready to download until it has been rendered' do
      expect(create(:loan_request).term_sheet_ready?).to be(false)
      expect(create(:loan_request, :rendered).term_sheet_ready?).to be(true)
      expect(create(:loan_request, :delivered).term_sheet_ready?).to be(true)
    end

    it 'rejects a status outside the lifecycle' do
      expect(build(:loan_request, status: 'posted')).not_to be_valid
    end

    it 'scopes undelivered requests for the requeue task' do
      create(:loan_request)
      create(:loan_request, :rendered)
      create(:loan_request, :delivered)

      expect(described_class.undelivered.count).to eq(2)
    end
  end

  describe '#explanation_for_display' do
    it 'computes one deterministically when none has been stored' do
      explanation = build(:loan_request).explanation_for_display

      expect(explanation.source).to eq(:rules)
      expect(explanation.headline).to include('$193,500.00')
    end

    it 'rehydrates the stored one' do
      loan_request = create(:loan_request, explanation: {
                              'headline' => 'Stored headline', 'bullets' => ['Stored bullet'],
                              'narrative' => 'Stored narrative', 'source' => 'claude'
                            })

      explanation = loan_request.explanation_for_display

      expect(explanation.headline).to eq('Stored headline')
      expect(explanation.narrative).to eq('Stored narrative')
      expect(explanation).to be_generated
    end
  end
end
