# frozen_string_literal: true

require 'rails_helper'

# The review step of the form. Its whole purpose is that the browser never
# calculates a lending figure.
RSpec.describe QuotesController, type: :controller do
  def post_quote(**overrides)
    post :create, format: :json, params: {
      quote: { product_code: 'fix_and_flip', loan_term: 6, purchase_price: 215_000,
               repair_budget: 48_000, arv: 340_000 }.merge(overrides)
    }
  end

  it 'prices a request without persisting anything' do
    expect { post_quote }.not_to change(LoanRequest, :count)
    expect(response).to have_http_status(:ok)
  end

  it 'returns the same figures the term sheet will show, to the cent' do
    post_quote
    formatted = response.parsed_body.dig('quote', 'formatted')

    expect(formatted['max_fundable_amount']).to eq('$193,500.00')
    expect(formatted['interest_expense']).to eq('$12,577.50')
    expect(formatted['total_repayment']).to eq('$206,077.50')
    expect(formatted['cash_required']).to eq('$69,500.00')
  end

  it 'returns exact decimal strings, never Floats, alongside the rendered figures' do
    post_quote
    quote = response.parsed_body['quote']

    expect(quote['max_fundable_amount']).to eq('193500.0')
    expect(quote['max_fundable_amount']).to be_a(String)
  end

  it 'includes the deterministic explanation' do
    post_quote
    explanation = response.parsed_body['explanation']

    expect(explanation['source']).to eq('rules')
    expect(explanation['headline']).to include('$193,500.00')
    expect(explanation['bullets']).to be_an(Array).and be_present
  end

  # A preview must never reach a language model: it fires on every arrival at
  # the review step and the borrower is waiting on it.
  it 'never calls the generated explainer, even with a key configured' do
    ENV['ANTHROPIC_API_KEY'] = 'sk-ant-test'
    allow(Lending::Explainers::Claude).to receive(:narrative)

    post_quote

    expect(Lending::Explainers::Claude).not_to have_received(:narrative)
  end

  it 'prices a different product differently' do
    post_quote(product_code: 'bridge', loan_term: 9, purchase_price: 410_000, repair_budget: 22_000, arv: 615_000)

    expect(response.parsed_body.dig('quote', 'formatted', 'max_fundable_amount')).to eq('$328,000.00')
  end

  it 'accepts figures the way a human types them' do
    post_quote(purchase_price: '$215,000', arv: ' 340000 ')

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('quote', 'formatted', 'max_fundable_amount')).to eq('$193,500.00')
  end

  describe 'bad input' do
    it 'rejects an unknown product without leaking the exception' do
      post_quote(product_code: 'mortgage')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['errors']).to eq(['That is not a product we offer.'])
    end

    it 'rejects a non-numeric figure' do
      post_quote(purchase_price: 'a lot')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['errors'].first).to include('could not price that')
    end

    it 'rejects a zero figure' do
      post_quote(arv: 0)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects a blank figure' do
      post_quote(repair_budget: '')
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'answers 400 when the quote key is missing' do
      post :create, format: :json, params: {}
      expect(response).to have_http_status(:bad_request)
    end
  end
end
