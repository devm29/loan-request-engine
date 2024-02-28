# frozen_string_literal: true

module Lending
  module Explainers
    # The deterministic explainer. Always available, never talks to anything,
    # and is the fallback whenever the generated one is unavailable or fails
    # the numeric guard.
    #
    # Every figure a borrower reads comes from here.
    module Rules
      module_function

      def call(quote)
        Explanation.new(
          headline: headline(quote),
          bullets: bullets(quote),
          narrative: narrative(quote),
          facts: facts(quote),
          source: :rules
        )
      end

      def headline(quote)
        "We can fund #{Format.currency(quote.max_fundable_amount)} on this #{quote.product.name} request."
      end

      def bullets(quote)
        [
          "#{Format.percent(quote.product.purchase_price_ltv)} of the " \
          "#{Format.currency(quote.purchase_price)} purchase price is " \
          "#{Format.currency(quote.purchase_price_cap)}.",
          "#{Format.percent(quote.product.arv_ltv)} of the " \
          "#{Format.currency(quote.arv)} after-repair value is " \
          "#{Format.currency(quote.arv_cap)}.",
          'The lower of the two caps applies, so the loan is ' \
          "#{Format.currency(quote.max_fundable_amount)}.",
          "You bring the remaining #{Format.currency(quote.cash_required)} of the " \
          "#{Format.currency(quote.total_project_cost)} project cost.",
          "Interest at #{Format.percent(quote.product.annual_interest_rate)} a year over " \
          "#{Format.months(quote.term_months)} is #{Format.currency(quote.interest_expense)}, " \
          "so #{Format.currency(quote.total_repayment)} is repayable at exit."
        ]
      end

      # Prose only - deliberately contains no figures, so that swapping in a
      # generated narrative changes tone and not arithmetic.
      def narrative(quote)
        case quote.binding_constraint
        when :purchase_price
          'The purchase price is what limits this loan: the after-repair value leaves ' \
          'headroom, so a higher purchase price (or a lower one, with the same exit) ' \
          'would move the funded amount directly.'
        when :arv
          'The after-repair value is what limits this loan. The purchase price alone ' \
          'would support more, so the exit valuation is the number to firm up - a ' \
          'stronger comp set is the fastest way to raise the funded amount.'
        else
          'Both caps land in the same place on this deal, so neither the purchase ' \
          'price nor the exit valuation has room on its own; moving the funded ' \
          'amount means moving both.'
        end
      end

      # The rendered figures a narrative is permitted to mention.
      def facts(quote)
        [
          Format.currency(quote.purchase_price),
          Format.currency(quote.repair_budget),
          Format.currency(quote.arv),
          Format.currency(quote.total_project_cost),
          Format.currency(quote.purchase_price_cap),
          Format.currency(quote.arv_cap),
          Format.currency(quote.max_fundable_amount),
          Format.currency(quote.interest_expense),
          Format.currency(quote.total_repayment),
          Format.currency(quote.cash_required),
          Format.currency(quote.estimated_profit),
          Format.percent(quote.product.purchase_price_ltv),
          Format.percent(quote.product.arv_ltv),
          Format.percent(quote.product.annual_interest_rate),
          Format.months(quote.term_months)
        ]
      end
    end
  end
end
