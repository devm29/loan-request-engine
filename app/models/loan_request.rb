# frozen_string_literal: true

# A borrower's request for a term sheet.
#
# This is a persistence and validation boundary only. None of the lending
# arithmetic lives here: it is delegated to Lending::Quote, which knows nothing
# about ActiveRecord and can therefore be tested to the cent without a database.
# The `calculate_*` methods are kept as the model's published surface and now
# read straight off the quote.
class LoanRequest < ApplicationRecord
  STATUSES = %w[submitted rendered delivered failed].freeze
  REFERENCE_BYTES = 9

  has_one_attached :term_sheet

  before_validation :normalize_email
  before_validation :assign_product_code
  before_validation :assign_reference, on: :create
  before_validation :assign_request_fingerprint

  validates :address, :loan_term, :purchase_price, :repair_budget, :arv, :first_name, :email, :phone, presence: true
  validates :purchase_price, numericality: { only_integer: true, greater_than: 0, message: 'must be a positive number' }
  validates :repair_budget, numericality: { only_integer: true, greater_than: 0, message: 'must be a positive number' }
  validates :arv, numericality: { only_integer: true, greater_than: 0, message: 'must be a positive number' }
  validates :loan_term, numericality: { only_integer: true, greater_than: 0, message: 'must be a positive number' }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :product_code, inclusion: { in: lambda { |_record|
    Lending::Catalog.codes
  }, message: 'is not a product we offer' }
  validates :status, inclusion: { in: STATUSES }
  validates :reference, presence: true, uniqueness: true
  validates :request_fingerprint, uniqueness: { message: 'has already been submitted' }, allow_nil: true
  validate :loan_term_within_product_range

  scope :undelivered, -> { where.not(status: 'delivered') }

  # The public identifier. Loan requests carry applicant PII, so nothing is
  # addressable by sequential id.
  def to_param
    reference
  end

  def product
    Lending::Catalog.find(product_code) || Lending::Catalog.default
  end

  # Recomputed whenever the inputs change, memoised while they do not: the
  # term sheet view reads half a dozen figures off one quote.
  def quote
    key = [product_code, purchase_price, repair_budget, arv, loan_term]
    return @quote if defined?(@quote) && @quote_key == key

    @quote_key = key
    @quote = Lending::Quote.new(
      product: product,
      purchase_price: purchase_price,
      repair_budget: repair_budget,
      arv: arv,
      term_months: loan_term
    )
  end

  # Applicant's display name. last_name is optional (nullable column), so it is
  # never concatenated directly.
  def full_name
    [first_name, last_name].reject { |part| part.to_s.strip.empty? }.join(' ')
  end

  # Returns the minimum of the purchase-price and ARV caps per lending policy,
  # truncated (not rounded) to the cent so the result can never exceed a cap.
  def calculate_max_fundable_amount
    quote.max_fundable_amount
  end

  # Total interest over the loan term at this product's annual rate, for an
  # arbitrary amount.
  def calculate_interest_expense(loan_amount)
    Lending::Quote.interest_expense(
      amount: loan_amount,
      annual_rate: product.annual_interest_rate,
      term_months: loan_term
    )
  end

  # Profit = ARV minus funded amount and interest expense.
  def calculate_profit
    quote.estimated_profit
  end

  STATUSES.each do |value|
    define_method(:"#{value}?") { status == value }
  end

  def term_sheet_ready?
    rendered? || delivered?
  end

  # The stored explanation, rehydrated. Falls back to the deterministic
  # explainer so a request whose job has not run yet still renders.
  def explanation_for_display
    stored = explanation.presence
    return Lending::Explainer.call(quote, backend: :rules) unless stored

    Lending::Explanation.new(
      headline: stored['headline'],
      bullets: Array(stored['bullets']),
      narrative: stored['narrative'],
      facts: Lending::Explainers::Rules.facts(quote),
      source: stored['source']
    )
  end

  private

  def normalize_email
    self.email = email.strip.downcase if email.is_a?(String)
  end

  def assign_product_code
    self.product_code = Lending::Catalog.default_code if product_code.blank?
  end

  def assign_reference
    self.reference ||= SecureRandom.urlsafe_base64(REFERENCE_BYTES)
  end

  def assign_request_fingerprint
    return if email.blank? || address.blank?

    self.request_fingerprint = Lending::RequestFingerprint.for(
      email: email, address: address, product_code: product_code,
      loan_term: loan_term, purchase_price: purchase_price,
      repair_budget: repair_budget, arv: arv
    )
  end

  def loan_term_within_product_range
    return if loan_term.blank? || !loan_term.is_a?(Integer)
    return if product.term_months_valid?(loan_term)

    errors.add(:loan_term, "must be between #{product.min_term_months} and #{product.max_term_months} months")
  end
end
