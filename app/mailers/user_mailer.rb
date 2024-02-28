# frozen_string_literal: true

# The one email this application sends: a borrower's term sheet, as a PDF
# attachment, dispatched from LoanProcessorJob once the PDF exists.
class UserMailer < ApplicationMailer
  TERMSHEET_FILENAME = 'termsheet.pdf'
  TERMSHEET_EMAIL_BODY = <<~BODY.strip
    Thank you for using our app. Here are those figures we promised.
    Please find attached your term sheet.
  BODY

  def termsheet_email(loan_request, pdf)
    attachments[TERMSHEET_FILENAME] = pdf
    mail(
      to: loan_request.email,
      subject: 'Your Term Sheet',
      body: TERMSHEET_EMAIL_BODY
    )
  end
end
