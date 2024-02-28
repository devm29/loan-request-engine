# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TermSheetsController, type: :controller do
  let(:loan_request) { create(:loan_request) }

  describe 'GET #show' do
    it 'renders the borrower their figures before the job has run' do
      get :show, params: { reference: loan_request.reference }

      expect(response).to render_template(:show)
      expect(assigns(:quote).max_fundable_amount).to eq(BigDecimal('193500'))
      expect(assigns(:explanation).source).to eq(:rules)
    end

    it 'is addressed by the unguessable reference, never the record id' do
      get :show, params: { reference: loan_request.id.to_s }
      expect(response).to redirect_to(root_path)
    end

    it 'sends an unknown reference back to the form rather than 404-ing blankly' do
      get :show, params: { reference: 'nope' }

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include('could not find')
    end
  end

  describe 'GET #status' do
    it 'reports not ready while the PDF is still rendering' do
      get :status, format: :json, params: { reference: loan_request.reference }
      body = response.parsed_body

      expect(body['ready']).to be(false)
      expect(body['status']).to eq('submitted')
      expect(body['document_url']).to be_nil
    end

    it 'reports ready with a download URL once the PDF exists' do
      rendered = create(:loan_request, :rendered)
      get :status, format: :json, params: { reference: rendered.reference }
      body = response.parsed_body

      expect(body['ready']).to be(true)
      expect(body['document_url']).to eq(term_sheet_document_path(rendered.reference))
    end

    it 'answers JSON 404 for an unknown reference' do
      get :status, format: :json, params: { reference: 'nope' }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET #document' do
    it 'sends the stored PDF inline' do
      rendered = create(:loan_request, :rendered)
      get :document, params: { reference: rendered.reference }

      expect(response).to have_http_status(:ok)
      expect(response.header['Content-Type']).to include('application/pdf')
      expect(response.header['Content-Disposition']).to include("term-sheet-#{rendered.reference}.pdf")
      expect(response.body).to eq('%PDF-1.4 test')
    end

    it 'sends the borrower back to wait when the PDF is not ready' do
      get :document, params: { reference: loan_request.reference }

      expect(response).to redirect_to(term_sheet_path(loan_request.reference))
      expect(flash[:alert]).to include('still being prepared')
    end
  end
end
