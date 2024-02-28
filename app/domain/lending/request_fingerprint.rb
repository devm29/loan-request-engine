# frozen_string_literal: true

require 'digest'

module Lending
  # A stable digest of the facts that make one loan request the same request.
  #
  # Two submissions with the same applicant, property, product and figures are
  # the same request - a double-clicked Submit button, a retried fetch, a
  # borrower resubmitting the form. Storing the digest under a unique index
  # makes the create endpoint idempotent, without blocking a returning
  # applicant from asking about a *different* property, which the previous
  # unique index on the email address did.
  module RequestFingerprint
    SEPARATOR = '|'

    module_function

    def for(email:, address:, product_code:, loan_term:, purchase_price:, repair_budget:, arv:)
      parts = [
        normalize(email),
        normalize(address),
        normalize(product_code),
        loan_term.to_i,
        purchase_price.to_i,
        repair_budget.to_i,
        arv.to_i
      ]
      Digest::SHA256.hexdigest(parts.join(SEPARATOR))
    end

    def normalize(value)
      value.to_s.strip.downcase.gsub(/\s+/, ' ')
    end
  end
end
