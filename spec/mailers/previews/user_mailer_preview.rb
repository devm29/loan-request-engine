# frozen_string_literal: true

# Visible at /rails/mailers/user_mailer/termsheet_email in development.
#
# Previews the real email against the most recent request in the database, with
# a placeholder attachment: rendering an actual PDF would need wkhtmltopdf on
# the machine viewing the preview, and the attachment is not what a preview is
# for.
class UserMailerPreview < ActionMailer::Preview
  def termsheet_email
    UserMailer.termsheet_email(loan_request, "%PDF-1.4\n% preview placeholder")
  end

  private

  def loan_request
    LoanRequest.last || LoanRequest.new(
      address: '1420 Chestnut Ridge Rd, Durham, NC 27703',
      product_code: Lending::Catalog.default_code, loan_term: 6,
      purchase_price: 215_000, repair_budget: 48_000, arv: 340_000,
      first_name: 'Dana', last_name: 'Whitfield',
      email: 'dana@ridgelinehomes.co', phone: '(919) 555-0142'
    )
  end
end
