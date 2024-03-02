# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LoanRequestsController, type: :controller do
  # Stubbed so the suite does not need a running Redis to enqueue Sidekiq jobs.
  before { allow(LoanProcessorJob).to receive(:perform_async) }

  describe 'GET #new' do
    it 'renders the form' do
      get :new

      expect(response).to render_template(:new)
      expect(assigns(:loan_request)).to be_a_new(LoanRequest)
    end

    it 'offers every catalogued product' do
      get :new
      expect(assigns(:products).map(&:code)).to match_array(Lending::Catalog.codes)
    end

    it 'preselects the default product' do
      get :new
      expect(assigns(:loan_request).product_code).to eq(Lending::Catalog.default_code)
    end
  end

  describe 'POST #create' do
    let(:valid_params) { { loan_request: attributes_for(:loan_request) } }

    context 'with valid attributes' do
      it 'creates the request' do
        expect { post :create, params: valid_params }.to change(LoanRequest, :count).by(1)
      end

      it 'redirects to the term sheet for that request, not back to the form' do
        post :create, params: valid_params
        expect(response).to redirect_to(term_sheet_path(LoanRequest.last.reference))
      end

      it 'sets a notice' do
        post :create, params: valid_params
        expect(flash[:notice]).to be_present
      end

      it 'answers JSON with the redirect target and the public reference' do
        post :create, format: :json, params: valid_params

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body['redirect_url']).to eq(term_sheet_path(LoanRequest.last.reference))
        expect(body['reference']).to eq(LoanRequest.last.reference)
      end

      it 'queues the term sheet rather than rendering it in the request' do
        post :create, params: valid_params
        expect(LoanProcessorJob).to have_received(:perform_async).with(LoanRequest.last.id)
      end

      it 'persists what was submitted' do
        attributes = attributes_for(:loan_request, purchase_price: 250_000, arv: 400_000)
        post :create, params: { loan_request: attributes }

        loan_request = LoanRequest.last
        expect(loan_request.purchase_price).to eq(250_000)
        expect(loan_request.arv).to eq(400_000)
        expect(loan_request.address).to eq(attributes[:address])
      end

      it 'records the chosen product' do
        post :create, params: { loan_request: attributes_for(:loan_request, product_code: 'bridge', loan_term: 9) }
        expect(LoanRequest.last.product_code).to eq('bridge')
      end
    end

    context 'when the same request is submitted twice' do
      it 'does not create a second record or send a second email' do
        post :create, params: valid_params
        expect { post :create, params: valid_params }.not_to change(LoanRequest, :count)
        expect(LoanProcessorJob).to have_received(:perform_async).once
      end

      it 'still sends the borrower to their term sheet' do
        post :create, params: valid_params
        post :create, params: valid_params

        expect(response).to redirect_to(term_sheet_path(LoanRequest.last.reference))
        expect(flash[:notice]).to include('already have this request')
      end
    end

    context 'with invalid attributes' do
      let(:invalid_params) { { loan_request: attributes_for(:loan_request, email: nil) } }

      it 'creates nothing' do
        expect { post :create, params: invalid_params }.not_to change(LoanRequest, :count)
      end

      it 'sets an alert' do
        post :create, params: invalid_params
        expect(flash[:alert]).to be_present
      end

      it 'queues nothing' do
        post :create, params: invalid_params
        expect(LoanProcessorJob).not_to have_received(:perform_async)
      end

      it 'answers JSON 422 with the error messages' do
        post :create, format: :json, params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['errors']).to be_an(Array).and be_present
      end

      it 'rejects an attribute that was not permitted' do
        post :create, params: { loan_request: attributes_for(:loan_request).merge(id: 999_999, status: 'delivered') }

        expect(LoanRequest.find_by(id: 999_999)).to be_nil
        expect(LoanRequest.last.status).to eq('submitted')
      end
    end

    context 'when the loan_request key is missing entirely' do
      it 'answers 400, not 500' do
        post :create, format: :json, params: {}

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['errors']).to be_an(Array)
      end
    end
  end
end
