# frozen_string_literal: true

module Lending
  # Canonical rendering of the figures in a quote.
  #
  # Kept in the domain, not in a view helper, for one reason: it is also the
  # source of the allow-list that Lending::NumericGuard checks a generated
  # narrative against. A figure is quotable only if it was rendered here.
  module Format
    module_function

    # "$180,000.00"
    def currency(value)
      amount = Money.round_to_cent(value)
      sign = amount.negative? ? '-' : ''
      whole, fraction = amount.abs.to_s('F').split('.')
      "#{sign}$#{with_thousands(whole)}.#{fraction.ljust(2, '0')[0, 2]}"
    end

    # "90%", "11.5%"
    def percent(fraction)
      value = Money.cast(fraction) * 100
      trimmed = value.round(4).to_s('F').sub(/\.?0+\z/, '')
      "#{trimmed}%"
    end

    # "6 months", "1 month"
    def months(count)
      n = Integer(count)
      "#{n} #{n == 1 ? 'month' : 'months'}"
    end

    def with_thousands(digits)
      digits.reverse.scan(/\d{1,3}/).join(',').reverse
    end
  end
end
