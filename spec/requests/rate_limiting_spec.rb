# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rate limiting on the public endpoints' do
  before do
    allow(LoanProcessorJob).to receive(:perform_async)
    Rack::Attack.enabled = true
    Rack::Attack.reset!
  end

  after { Rack::Attack.enabled = false }

  def submit(index)
    post loan_requests_path(format: :json),
         params: { loan_request: attributes_for(:loan_request, address: "#{index} Oak Row, Durham, NC 27701") }
  end

  it 'lets five submissions a minute through and refuses the sixth with JSON' do
    5.times { |index| submit(index) }
    expect(response).to have_http_status(:ok)

    submit(6)
    expect(response).to have_http_status(:too_many_requests)
    expect(response.media_type).to eq('application/json')
    expect(response.parsed_body['errors'].first).to include('Too many requests')
  end

  it 'cannot be stepped around with a trailing slash or a format extension' do
    3.times { |index| submit(index) }
    post '/loan_requests/', params: { loan_request: attributes_for(:loan_request) }, as: :json
    post '/loan_requests.json', params: { loan_request: attributes_for(:loan_request) }
    expect(response).to have_http_status(:ok)

    post '/loan_requests', params: { loan_request: attributes_for(:loan_request) }, as: :json
    expect(response).to have_http_status(:too_many_requests)
  end

  it 'counts each client address separately' do
    5.times { |index| submit(index) }

    post loan_requests_path(format: :json),
         params: { loan_request: attributes_for(:loan_request) },
         headers: { 'REMOTE_ADDR' => '203.0.113.9' }
    expect(response).to have_http_status(:ok)
  end

  it 'allows thirty quote previews a minute' do
    params = { quote: { product_code: 'fix_and_flip', loan_term: 6, purchase_price: 215_000,
                        repair_budget: 48_000, arv: 340_000 } }
    30.times { post quotes_path, params: params, as: :json }
    expect(response).to have_http_status(:ok)

    post quotes_path, params: params, as: :json
    expect(response).to have_http_status(:too_many_requests)
  end
end
