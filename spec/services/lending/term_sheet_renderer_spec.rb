# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lending::TermSheetRenderer do
  let(:loan_request) { create(:loan_request) }
  let(:rendered_html) { [] }

  before do
    wicked_pdf = instance_double(WickedPdf)
    allow(WickedPdf).to receive(:new).and_return(wicked_pdf)
    allow(wicked_pdf).to receive(:pdf_from_string) do |html|
      rendered_html << html
      'PDF-BYTES'
    end
  end

  it 'returns the PDF bytes' do
    expect(described_class.call(loan_request)).to eq('PDF-BYTES')
  end

  it 'renders the real term sheet template' do
    described_class.call(loan_request)

    expect(rendered_html.first).to include('Loan Request Term Sheet')
    expect(rendered_html.first).to include(loan_request.address)
    expect(rendered_html.first).to include(loan_request.email)
  end

  it 'prints the figures the quote computed, to the cent' do
    described_class.call(loan_request)

    expect(rendered_html.first).to include('$193,500.00') # max fundable
    expect(rendered_html.first).to include('$12,577.50')  # interest over 6 months
    expect(rendered_html.first).to include('$69,500.00')  # cash required
  end

  it 'prints the public reference, never the database id' do
    described_class.call(loan_request)

    expect(rendered_html.first).to include(loan_request.reference)
  end

  # The application layout needs a live request (CSRF and CSP meta tags,
  # Webpacker helpers) that a background job does not have, and would nest a
  # second <html> document inside the term sheet.
  it 'does not wrap the term sheet in the application layout' do
    described_class.call(loan_request)

    expect(rendered_html.first.scan('<html').size).to eq(1)
    expect(rendered_html.first).not_to include('csrf-token')
  end

  it 'renders an applicant with no last name' do
    loan_request.update!(last_name: nil)

    expect { described_class.call(loan_request) }.not_to raise_error
    expect(rendered_html.first).to include(loan_request.first_name)
  end

  it 'renders before the explanation has been persisted' do
    expect(loan_request.explanation).to be_nil
    described_class.call(loan_request)

    expect(rendered_html.first).to include('We can fund $193,500.00')
  end
end
