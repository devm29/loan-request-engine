# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'application routing', type: :routing do
  it 'routes the root path to the loan request form' do
    expect(get: '/').to route_to('loan_requests#new')
  end

  it 'routes POST /loan_requests to create' do
    expect(post: '/loan_requests').to route_to('loan_requests#create')
  end

  it 'routes the quote preview' do
    expect(post: '/quotes').to route_to('quotes#create')
  end

  it 'routes a term sheet by its reference' do
    expect(get: '/term-sheets/abc123').to route_to('term_sheets#show', reference: 'abc123')
  end

  it 'routes the status poll and the document download' do
    expect(get: '/term-sheets/abc123/status').to route_to('term_sheets#status', reference: 'abc123')
    expect(get: '/term-sheets/abc123/document.pdf').to route_to('term_sheets#document', reference: 'abc123')
  end

  it 'routes the container healthcheck' do
    expect(get: '/up').to route_to('health#show')
  end

  # The app has no authentication, so nothing beyond the public form and a
  # reference-addressed term sheet may be routable: index/show/edit/update/
  # destroy on loan requests would expose applicant PII.
  it 'does not expose any other loan request action' do
    expect(get: '/loan_requests').not_to be_routable
    expect(get: '/loan_requests/1').not_to be_routable
    expect(get: '/loan_requests/1/edit').not_to be_routable
    expect(patch: '/loan_requests/1').not_to be_routable
    expect(delete: '/loan_requests/1').not_to be_routable
  end
end
