# frozen_string_literal: true

module Lending
  # Renders a loan request's term sheet to PDF bytes.
  #
  # Rendered without a layout: the term sheet template is a complete HTML
  # document, and the application layout needs a live request (CSRF/CSP meta
  # tags, Webpacker helpers) that a background job does not have.
  module TermSheetRenderer
    TEMPLATE = 'loan_requests/termsheet'

    module_function

    def call(loan_request)
      WickedPdf.new.pdf_from_string(html_for(loan_request))
    end

    def html_for(loan_request)
      ApplicationController.render(
        template: TEMPLATE,
        formats: [:pdf],
        layout: false,
        locals: { loan_request: loan_request, explanation: loan_request.explanation_for_display }
      )
    end
  end
end
