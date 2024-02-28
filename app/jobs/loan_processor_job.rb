# frozen_string_literal: true

# Renders a term sheet and emails it.
#
# This is the whole reason the application has a queue: wkhtmltopdf spawns a
# process and takes hundreds of milliseconds to seconds, and an SMTP round trip
# can take longer still. Neither belongs in the request that a borrower is
# waiting on, and neither is something to retry by asking them to submit again.
#
# The job is idempotent so that a retry is cheap and safe: an already-delivered
# request returns immediately, and a request whose PDF is already in storage
# reuses it rather than re-rendering. That matters because the expensive step
# (rendering) and the flaky step (delivery) share a job - a bounced SMTP
# connection must not cost another wkhtmltopdf run.
class LoanProcessorJob
  include Sidekiq::Job

  # Retries run on Sidekiq's exponential backoff. Ten attempts spans a little
  # over a day, which covers a mail provider outage without pestering the
  # borrower's inbox if delivery eventually succeeds twice.
  sidekiq_options queue: :term_sheets, retry: 10, backtrace: 20

  sidekiq_retries_exhausted do |job, exception|
    loan_request = LoanRequest.find_by(id: job['args'].first)
    # update_columns deliberately: this is the last thing that runs for this
    # request, and a validation or callback failing here would swallow the
    # record of *why* it failed.
    loan_request&.update_columns( # rubocop:disable Rails/SkipsModelValidations
      status: 'failed',
      failure_reason: "#{exception.class}: #{exception.message}"[0, 255]
    )
    Rails.logger.error("LoanProcessorJob exhausted retries for loan_request_id=#{job['args'].first}")
  end

  def perform(loan_request_id)
    loan_request = LoanRequest.find_by(id: loan_request_id)
    unless loan_request
      Rails.logger.error("LoanProcessorJob: LoanRequest not found for ID #{loan_request_id}")
      return
    end

    return if loan_request.delivered?

    ensure_explanation(loan_request)
    pdf = stored_pdf(loan_request) || render_and_store(loan_request)
    UserMailer.termsheet_email(loan_request, pdf).deliver_now
    loan_request.update!(status: 'delivered', delivered_at: Time.current, failure_reason: nil)
  rescue StandardError => e
    # Log and re-raise so Sidekiq can retry the job per its retry configuration.
    Rails.logger.error("LoanProcessorJob failed for loan_request_id=#{loan_request_id}: #{e.class} - #{e.message}")
    raise
  end

  private

  # The explanation may involve a network call, so it happens here rather than
  # in the request, and is persisted so a retry does not repeat it.
  def ensure_explanation(loan_request)
    return if loan_request.explanation.present?

    loan_request.update!(explanation: Lending::Explainer.call(loan_request.quote).to_h)
  end

  def stored_pdf(loan_request)
    return nil unless loan_request.term_sheet.attached?

    loan_request.term_sheet.download
  end

  def render_and_store(loan_request)
    pdf = generate_pdf(loan_request)
    loan_request.term_sheet.attach(
      io: StringIO.new(pdf),
      filename: UserMailer::TERMSHEET_FILENAME,
      content_type: 'application/pdf'
    )
    loan_request.update!(status: 'rendered')
    pdf
  end

  def generate_pdf(loan_request)
    Lending::TermSheetRenderer.call(loan_request)
  end
end
