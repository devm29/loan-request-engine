# frozen_string_literal: true

# Adds the product seam, the public reference, the idempotency fingerprint and
# the delivery lifecycle.
#
# It also drops the unique index on `email`. That index made the form usable
# exactly once per applicant: a borrower asking about a second property was
# told their email "has already been taken". Idempotency is what the index was
# reaching for, and `request_fingerprint` expresses it properly - the same
# applicant, property, product and figures is the same request; a different
# property is not.
class AddProductAndDeliveryToLoanRequests < ActiveRecord::Migration[6.1]
  # Minimal shim so the backfill does not depend on the app model, which has
  # validations and callbacks that assume the final schema.
  class BackfillLoanRequest < ActiveRecord::Base
    self.table_name = 'loan_requests'
  end

  def up
    add_column :loan_requests, :product_code, :string, null: false, default: 'fix_and_flip'
    add_column :loan_requests, :status, :string, null: false, default: 'submitted'
    add_column :loan_requests, :reference, :string
    add_column :loan_requests, :request_fingerprint, :string
    add_column :loan_requests, :explanation, :jsonb
    add_column :loan_requests, :delivered_at, :datetime
    add_column :loan_requests, :failure_reason, :string

    backfill_references_and_fingerprints

    change_column_null :loan_requests, :reference, false
    change_column_null :loan_requests, :request_fingerprint, false

    remove_index :loan_requests, column: :email, name: 'index_loan_requests_on_email'
    add_index :loan_requests, :email
    add_index :loan_requests, :reference, unique: true
    add_index :loan_requests, :request_fingerprint, unique: true
    # Supports `rake lending:requeue_stalled`, which is the only query that
    # ever scans for requests that have not been delivered.
    add_index :loan_requests, %i[status created_at],
              where: "status <> 'delivered'", name: 'index_loan_requests_undelivered'

    # Terms are capped per product now (see config/lending_products.yml); the
    # database keeps a sanity bound wide enough for every product we offer.
    remove_check_constraint :loan_requests, name: 'loan_term_range'
    add_check_constraint :loan_requests, '(loan_term > 0) AND (loan_term <= 36)', name: 'loan_term_range'
  end

  def down
    remove_check_constraint :loan_requests, name: 'loan_term_range'
    add_check_constraint :loan_requests, '(loan_term > 0) AND (loan_term <= 12)', name: 'loan_term_range'

    remove_index :loan_requests, name: 'index_loan_requests_undelivered'
    remove_index :loan_requests, column: :request_fingerprint
    remove_index :loan_requests, column: :reference
    remove_index :loan_requests, column: :email
    add_index :loan_requests, :email, unique: true, name: 'index_loan_requests_on_email'

    remove_column :loan_requests, :failure_reason
    remove_column :loan_requests, :delivered_at
    remove_column :loan_requests, :explanation
    remove_column :loan_requests, :request_fingerprint
    remove_column :loan_requests, :reference
    remove_column :loan_requests, :status
    remove_column :loan_requests, :product_code
  end

  private

  def backfill_references_and_fingerprints
    BackfillLoanRequest.reset_column_information
    BackfillLoanRequest.where(reference: nil).find_each do |record|
      record.update_columns(
        reference: SecureRandom.urlsafe_base64(9),
        request_fingerprint: Lending::RequestFingerprint.for(
          email: record.email, address: record.address, product_code: 'fix_and_flip',
          loan_term: record.loan_term, purchase_price: record.purchase_price,
          repair_budget: record.repair_budget, arv: record.arv
        )
      )
    end
  end
end
