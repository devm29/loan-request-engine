# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lending::Explainers::Rules do
  subject(:explanation) { described_class.call(quote) }

  let(:quote) { build_quote(purchase_price: 215_000, repair_budget: 48_000, arv: 340_000, term_months: 6) }

  it 'is always available and always marked as deterministic' do
    expect(explanation.source).to eq(:rules)
    expect(explanation).not_to be_generated
  end

  it 'leads with the amount we can fund' do
    expect(explanation.headline).to include('$193,500.00')
  end

  it 'shows both caps and says which one applied' do
    joined = explanation.bullets.join(' ')

    expect(joined).to include('90%').and include('$193,500.00')
    expect(joined).to include('70%').and include('$238,000.00')
    expect(joined).to include('The lower of the two caps applies')
  end

  it 'states the cash the borrower brings' do
    expect(explanation.bullets.join(' ')).to include('$69,500.00')
  end

  it 'states the interest and the exit repayment' do
    expect(explanation.bullets.join(' ')).to include('$12,577.50').and include('$206,077.50')
  end

  # The narrative is the half a language model may replace. Keeping it free of
  # figures is what makes that swap safe.
  it 'writes a narrative containing no figures at all' do
    expect(explanation.narrative).not_to match(/\d/)
  end

  it 'explains the purchase price binding when it binds' do
    expect(explanation.narrative).to include('purchase price is what limits this loan')
  end

  it 'explains the ARV binding when that binds instead' do
    arv_bound = described_class.call(build_quote(purchase_price: 300_000, arv: 300_000))
    expect(arv_bound.narrative).to include('after-repair value is what limits this loan')
  end

  it 'explains the case where both caps coincide' do
    both = described_class.call(build_quote(purchase_price: 210_000, arv: 270_000))
    expect(both.narrative).to include('Both caps land in the same place')
  end

  it 'vouches for every figure its own bullets state' do
    joined = "#{explanation.bullets.join(' ')} #{explanation.headline}"
    expect(Lending::NumericGuard.unvouched_tokens(joined, facts: explanation.facts)).to be_empty
  end
end
