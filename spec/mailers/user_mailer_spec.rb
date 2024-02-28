# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserMailer, type: :mailer do
  let(:loan_request) { create(:loan_request, email: 'borrower@example.com') }
  let(:pdf_content) { '%PDF-1.4 fake' }
  let(:mail) { described_class.termsheet_email(loan_request, pdf_content) }

  it 'sends to the applicant' do
    expect(mail.to).to eq(['borrower@example.com'])
  end

  it 'sets the subject' do
    expect(mail.subject).to eq('Your Term Sheet')
  end

  it 'explains what is attached' do
    expect(mail.body.encoded).to include('term sheet')
  end

  it 'attaches exactly one PDF, named for a human' do
    expect(mail.attachments.size).to eq(1)
    expect(mail.attachments.first.filename).to eq(described_class::TERMSHEET_FILENAME)
    expect(mail.attachments.first.content_type).to include('application/pdf')
    expect(mail.attachments.first.body.raw_source).to eq(pdf_content)
  end

  it 'sends from the configured address' do
    expect(mail.from).to be_present
  end
end
