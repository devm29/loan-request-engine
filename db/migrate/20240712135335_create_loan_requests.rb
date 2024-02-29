# frozen_string_literal: true

class CreateLoanRequests < ActiveRecord::Migration[6.1]
  def change
    create_table :loan_requests do |t|
      t.string :address, null: false
      t.integer :loan_term, null: false
      t.integer :purchase_price, null: false
      t.integer :repair_budget, null: false
      t.integer :arv, null: false
      t.string :first_name, null: false
      t.string :last_name
      t.string :email, null: false
      t.string :phone, null: false

      t.timestamps
    end

    add_index :loan_requests, :email, unique: true

    add_check_constraint :loan_requests, 'loan_term > 0 AND loan_term <= 12', name: 'loan_term_range'
    add_check_constraint :loan_requests, 'purchase_price > 0', name: 'purchase_price_positive'
    add_check_constraint :loan_requests, 'repair_budget > 0', name: 'repair_budget_positive'
    add_check_constraint :loan_requests, 'arv > 0', name: 'arv_positive'
  end
end
