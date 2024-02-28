# frozen_string_literal: true

require 'rails_helper'

# Without JavaScript the form posts as plain HTML and the borrower lands on
# another page. These follow that redirect, because a message set for the
# current request only (flash.now) is gone by the time the next page renders.
RSpec.describe 'Loan request form without JavaScript' do
  before { allow(LoanProcessorJob).to receive(:perform_async) }

  let(:attributes) { attributes_for(:loan_request) }

  it 'shows the confirmation on the term sheet page' do
    post loan_requests_path, params: { loan_request: attributes }
    follow_redirect!

    expect(response.body).to include('Loan request was successfully created.')
    expect(response.body).to include(attributes[:address])
  end

  it 'tells a repeat submitter it already has their request' do
    2.times { post loan_requests_path, params: { loan_request: attributes } }
    follow_redirect!

    expect(response.body).to include('We already have this request.')
  end

  it 'explains what was wrong when the request is rejected' do
    post loan_requests_path, params: { loan_request: attributes.merge(email: '') }
    follow_redirect!

    expect(response.body).to include('Loan request could not be saved')
    expect(response.body).to include('Email can&#39;t be blank')
  end
end
