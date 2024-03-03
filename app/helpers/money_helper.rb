# frozen_string_literal: true

# Views format money through the domain, not through number_to_currency.
#
# The same renderer produces the figures on screen, the figures on the PDF and
# the allow-list Lending::NumericGuard checks a generated narrative against, so
# the three cannot disagree about what a number looks like.
module MoneyHelper
  def money(value)
    Lending::Format.currency(value)
  end

  def percentage(fraction)
    Lending::Format.percent(fraction)
  end

  def months(count)
    Lending::Format.months(count)
  end
end
