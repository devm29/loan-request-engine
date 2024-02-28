# frozen_string_literal: true

# What a borrower sees after submitting: their figures immediately, and the
# PDF as soon as the background job has rendered it.
#
# The page is useful before the job finishes - the quote is recomputed from the
# stored request, so nothing here waits on the queue. Only the download waits.
class TermSheetsController < ApplicationController
  before_action :set_loan_request

  def show
    @quote = @loan_request.quote
    @explanation = @loan_request.explanation_for_display
  end

  # Polled by the page until the PDF exists, so the borrower is not asked to
  # refresh.
  def status
    render json: {
      status: @loan_request.status,
      ready: @loan_request.term_sheet.attached?,
      document_url: @loan_request.term_sheet.attached? ? term_sheet_document_path(@loan_request.reference) : nil
    }
  end

  def document
    unless @loan_request.term_sheet.attached?
      redirect_to term_sheet_path(@loan_request.reference),
                  alert: 'Your term sheet is still being prepared. Try again in a moment.'
      return
    end

    send_data @loan_request.term_sheet.download,
              filename: "term-sheet-#{@loan_request.reference}.pdf",
              type: 'application/pdf',
              disposition: 'inline'
  end

  private

  def set_loan_request
    @loan_request = LoanRequest.find_by(reference: params[:reference])
    return if @loan_request

    respond_to do |format|
      format.html { redirect_to root_path, alert: 'We could not find that term sheet.' }
      format.json { render json: { errors: ['not found'] }, status: :not_found }
    end
  end
end
