# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LoanProcessorJob, type: :job do
  let(:loan_request) { create(:loan_request) }
  let(:mailer) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }

  before do
    allow(Lending::TermSheetRenderer).to receive(:call).and_return('PDF-BYTES')
    allow(UserMailer).to receive(:termsheet_email).and_return(mailer)
  end

  describe 'the happy path' do
    it 'renders the PDF, emails it and records delivery' do
      described_class.new.perform(loan_request.id)

      expect(Lending::TermSheetRenderer).to have_received(:call).with(loan_request)
      expect(UserMailer).to have_received(:termsheet_email).with(loan_request, 'PDF-BYTES')
      expect(mailer).to have_received(:deliver_now)
      expect(loan_request.reload).to be_delivered
      expect(loan_request.delivered_at).to be_present
    end

    it 'stores the PDF in Active Storage rather than on local disk' do
      described_class.new.perform(loan_request.id)

      expect(loan_request.reload.term_sheet).to be_attached
      expect(loan_request.term_sheet.download).to eq('PDF-BYTES')
      expect(loan_request.term_sheet.content_type).to eq('application/pdf')
    end

    it 'persists the explanation so a retry does not recompute it' do
      described_class.new.perform(loan_request.id)

      expect(loan_request.reload.explanation).to include('headline', 'bullets', 'narrative', 'source')
      expect(loan_request.explanation['headline']).to include('$193,500.00')
    end
  end

  # Rendering is the expensive step and delivery is the flaky one; they share a
  # job, so a bounced SMTP connection must not cost another wkhtmltopdf run.
  describe 'idempotency' do
    it 'does nothing at all for an already-delivered request' do
      delivered = create(:loan_request, :delivered)
      described_class.new.perform(delivered.id)

      expect(Lending::TermSheetRenderer).not_to have_received(:call)
      expect(UserMailer).not_to have_received(:termsheet_email)
    end

    it 'reuses a PDF already in storage instead of re-rendering' do
      rendered = create(:loan_request, :rendered)
      described_class.new.perform(rendered.id)

      expect(Lending::TermSheetRenderer).not_to have_received(:call)
      expect(UserMailer).to have_received(:termsheet_email).with(rendered, '%PDF-1.4 test')
    end

    it 'does not recompute an explanation it already has' do
      loan_request.update!(explanation: { 'headline' => 'Kept', 'bullets' => [], 'narrative' => '',
                                          'source' => 'rules' })
      allow(Lending::Explainer).to receive(:call)

      described_class.new.perform(loan_request.id)

      expect(Lending::Explainer).not_to have_received(:call)
      expect(loan_request.reload.explanation['headline']).to eq('Kept')
    end

    it 'runs twice without attaching the PDF twice' do
      described_class.new.perform(loan_request.id)
      described_class.new.perform(loan_request.id)

      expect(loan_request.reload.term_sheet.attachments.size).to eq(1)
    end
  end

  describe 'failure handling' do
    it 'logs and returns when the request no longer exists' do
      allow(Rails.logger).to receive(:error)

      expect { described_class.new.perform(-1) }.not_to raise_error
      expect(Rails.logger).to have_received(:error).with(/LoanRequest not found for ID -1/)
    end

    it 're-raises so Sidekiq retries, after logging' do
      allow(Lending::TermSheetRenderer).to receive(:call).and_raise(StandardError, 'wkhtmltopdf died')
      allow(Rails.logger).to receive(:error)

      expect { described_class.new.perform(loan_request.id) }.to raise_error(StandardError, 'wkhtmltopdf died')
      expect(Rails.logger).to have_received(:error).with(/LoanProcessorJob failed/)
    end

    it 'does not mark a request delivered when the mail fails' do
      allow(mailer).to receive(:deliver_now).and_raise(Net::SMTPServerBusy.new('mail server busy'))

      expect { described_class.new.perform(loan_request.id) }.to raise_error(Net::SMTPServerBusy)
      expect(loan_request.reload).not_to be_delivered
    end

    it 'keeps the rendered PDF when only the mail failed' do
      allow(mailer).to receive(:deliver_now).and_raise(Net::SMTPServerBusy.new('mail server busy'))

      expect { described_class.new.perform(loan_request.id) }.to raise_error(Net::SMTPServerBusy)
      expect(loan_request.reload.term_sheet).to be_attached
      expect(loan_request).to be_rendered
    end

    it 'records the reason when retries are exhausted' do
      described_class.sidekiq_retries_exhausted_block.call(
        { 'args' => [loan_request.id] }, StandardError.new('gave up')
      )

      expect(loan_request.reload).to be_failed
      expect(loan_request.failure_reason).to include('gave up')
    end
  end

  describe 'queue configuration' do
    it 'runs on its own queue with a retry budget that spans a mail outage' do
      expect(described_class.sidekiq_options['queue'].to_s).to eq('term_sheets')
      expect(described_class.sidekiq_options['retry']).to eq(10)
    end
  end
end
