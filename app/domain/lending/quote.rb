# frozen_string_literal: true

module Lending
  # The whole of the lending arithmetic, in one dependency-free object.
  #
  # Nothing here touches ActiveRecord, Rails, the network or the clock: a quote
  # is a pure function of a product and four numbers, which is what makes it
  # cheap to pin to the cent in tests. Everything it returns is a BigDecimal.
  #
  # Rounding policy - the two directions are deliberately different:
  #
  #   * policy caps are TRUNCATED to the cent (Money.floor_to_cent), so a
  #     rounding step can never produce an amount above the cap it came from;
  #   * the interest charge is ROUNDED half-up to the cent, because a rate
  #     applied over a term rarely lands on a whole cent and rounding the
  #     charge to the nearest cent is the fair reading of "13% annual".
  #
  # The interest expression multiplies before it divides -
  # `amount * rate * months / 12`, not `amount * (rate / 12) * months` - so the
  # non-terminating monthly rate is never materialised and then re-rounded.
  # The second form is what produced $6,500.84 where $6,500.85 was owed.
  class Quote
    MONTHS_PER_YEAR = 12

    attr_reader :product, :purchase_price, :repair_budget, :arv, :term_months

    # Interest over `term_months` on `amount` at `annual_rate`, simple interest
    # accrued monthly. Exposed as a class method because it is a pure function
    # and is useful on amounts other than the one this quote funds.
    def self.interest_expense(amount:, annual_rate:, term_months:)
      months = Integer(term_months)
      Money.round_to_cent(
        Money.cast(amount) * Money.cast(annual_rate) * months / MONTHS_PER_YEAR
      )
    end

    def initialize(product:, purchase_price:, repair_budget:, arv:, term_months:)
      @product = product
      @purchase_price = Money.cast(purchase_price)
      @repair_budget = Money.cast(repair_budget)
      @arv = Money.cast(arv)
      @term_months = Integer(term_months)
    end

    # The most this product will lend: the lower of the two policy caps,
    # truncated to the cent.
    def max_fundable_amount
      @max_fundable_amount ||= Money.floor_to_cent([uncapped_purchase_price_cap, uncapped_arv_cap].min)
    end

    # 90% (say) of the purchase price, truncated to the cent.
    def purchase_price_cap
      @purchase_price_cap ||= Money.floor_to_cent(uncapped_purchase_price_cap)
    end

    # 70% (say) of the after-repair value, truncated to the cent.
    def arv_cap
      @arv_cap ||= Money.floor_to_cent(uncapped_arv_cap)
    end

    # Which policy cap actually limited the loan: :purchase_price, :arv, or
    # :both when they coincide. Drives the explanation shown to the borrower.
    def binding_constraint
      if uncapped_purchase_price_cap == uncapped_arv_cap
        :both
      elsif uncapped_purchase_price_cap < uncapped_arv_cap
        :purchase_price
      else
        :arv
      end
    end

    def interest_expense
      @interest_expense ||= self.class.interest_expense(
        amount: max_fundable_amount,
        annual_rate: product.annual_interest_rate,
        term_months: term_months
      )
    end

    def total_repayment
      max_fundable_amount + interest_expense
    end

    # What the borrower has to bring: total project cost less what we fund.
    # Cannot be negative - the purchase-price cap is at most 100% of the
    # purchase price, and the project also carries the repair budget.
    def cash_required
      total_project_cost - max_fundable_amount
    end

    def total_project_cost
      purchase_price + repair_budget
    end

    # ARV less the funded amount and the interest on it. Unchanged from the
    # original definition; see README "Design notes".
    def estimated_profit
      Money.round_to_cent(arv - max_fundable_amount - interest_expense)
    end

    def term_within_product_range?
      product.term_months_valid?(term_months)
    end

    def to_h
      { product_code: product.code,
        product_name: product.name,
        term_months: term_months,
        purchase_price: purchase_price,
        repair_budget: repair_budget,
        arv: arv,
        total_project_cost: total_project_cost,
        purchase_price_cap: purchase_price_cap,
        arv_cap: arv_cap,
        max_fundable_amount: max_fundable_amount,
        binding_constraint: binding_constraint,
        interest_expense: interest_expense,
        total_repayment: total_repayment,
        cash_required: cash_required,
        estimated_profit: estimated_profit }
    end

    private

    def uncapped_purchase_price_cap
      @uncapped_purchase_price_cap ||= purchase_price * product.purchase_price_ltv
    end

    def uncapped_arv_cap
      @uncapped_arv_cap ||= arv * product.arv_ltv
    end
  end
end
