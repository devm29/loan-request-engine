# frozen_string_literal: true

# Three realistic requests, one per product, so the application is not empty on
# first boot and every branch of the pricing logic is visible:
#
#   * Chestnut Ridge  - the ARV cap binds (the exit valuation is the limit)
#   * Sawtooth Ave    - the purchase-price cap binds (loan-to-cost is the limit)
#   * Harlow Lot 14   - a ground-up build near the top of its term window
#
# Idempotent: re-running it re-uses the existing request rather than creating a
# second one, because the fingerprint is the same. Safe to run on every boot.

SEEDS = [
  {
    product_code: 'fix_and_flip',
    address: '1420 Chestnut Ridge Rd, Durham, NC 27703',
    loan_term: 6,
    purchase_price: 215_000,
    repair_budget: 48_000,
    arv: 340_000,
    first_name: 'Dana',
    last_name: 'Whitfield',
    email: 'dana@ridgelinehomes.co',
    phone: '(919) 555-0142'
  },
  {
    product_code: 'bridge',
    address: '88 Sawtooth Ave, Asheville, NC 28801',
    loan_term: 9,
    purchase_price: 410_000,
    repair_budget: 22_000,
    arv: 615_000,
    first_name: 'Marcus',
    last_name: 'Oyelaran',
    email: 'marcus@sawtoothcapital.co',
    phone: '(828) 555-0119'
  },
  {
    product_code: 'new_construction',
    address: 'Harlow Farm Lot 14, Raleigh, NC 27610',
    loan_term: 15,
    purchase_price: 128_000,
    repair_budget: 296_000,
    arv: 585_000,
    first_name: 'Priya',
    last_name: 'Raghunathan',
    email: 'priya@harlowbuild.co',
    phone: '(984) 555-0173'
  }
].freeze

SEEDS.each do |attributes|
  result = Lending::SubmitLoanRequest.call(attributes)
  loan_request = result.loan_request

  unless result.success?
    warn "  ! skipped #{attributes[:address]}: #{loan_request.errors.full_messages.join(', ')}"
    next
  end

  verb = result.duplicate? ? 'exists' : 'created'
  quote = loan_request.quote
  puts format(
    '  %<verb>-8s %<address>-34s %<reference>-16s max loan %<amount>s (%<binding>s cap binds)',
    verb: verb,
    address: attributes[:address][0, 32],
    reference: loan_request.reference,
    amount: Lending::Format.currency(quote.max_fundable_amount),
    binding: quote.binding_constraint
  )
end

puts "  #{LoanRequest.count} loan request(s) in the database."
