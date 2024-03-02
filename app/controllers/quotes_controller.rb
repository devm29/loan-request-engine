# frozen_string_literal: true

# Server-computed quote preview for the review step of the form.
#
# Nothing is persisted and nothing is emailed; this exists so a borrower can
# see the figures before committing, and so that the browser never does any
# lending arithmetic of its own. The same Lending::Quote produces the preview
# and the term sheet, so the two cannot disagree.
class QuotesController < ApplicationController
  rescue_from ActionController::ParameterMissing, with: :render_parameter_missing

  def create
    quote = Lending::Quote.new(
      product: product,
      purchase_price: money(:purchase_price),
      repair_budget: money(:repair_budget),
      arv: money(:arv),
      term_months: Integer(quote_params[:loan_term].to_s)
    )

    render json: {
      quote: presented(quote),
      explanation: Lending::Explainer.call(quote, backend: :rules).to_h
    }
  # ActionController::ParameterMissing is deliberately absent: a request with
  # no `quote` key at all is malformed (400), not unpriceable (422), and is
  # handled by the rescue_from above. It subclasses KeyError, which is why
  # KeyError is not caught here either.
  rescue Lending::Catalog::UnknownProduct, Lending::Money::FloatError, ArgumentError, TypeError => e
    render json: { errors: [preview_error_message(e)] }, status: :unprocessable_entity
  end

  private

  def product
    Lending::Catalog.fetch(quote_params[:product_code].presence || Lending::Catalog.default_code)
  end

  # Inputs arrive as strings from the form and stay strings all the way into
  # BigDecimal; they are never routed through Float.
  def money(key)
    raw = quote_params[key].to_s.delete(',$ ').strip
    raise ArgumentError, "#{key} is required" if raw.empty?

    amount = Lending::Money.cast(raw)
    raise ArgumentError, "#{key} must be greater than zero" unless amount.positive?

    amount
  end

  def presented(quote)
    quote.to_h.transform_values { |value| value.is_a?(BigDecimal) ? value.to_s('F') : value }
         .merge(formatted: formatted(quote))
  end

  def formatted(quote)
    {
      purchase_price: Lending::Format.currency(quote.purchase_price),
      repair_budget: Lending::Format.currency(quote.repair_budget),
      arv: Lending::Format.currency(quote.arv),
      total_project_cost: Lending::Format.currency(quote.total_project_cost),
      max_fundable_amount: Lending::Format.currency(quote.max_fundable_amount),
      interest_expense: Lending::Format.currency(quote.interest_expense),
      total_repayment: Lending::Format.currency(quote.total_repayment),
      cash_required: Lending::Format.currency(quote.cash_required),
      estimated_profit: Lending::Format.currency(quote.estimated_profit),
      term: Lending::Format.months(quote.term_months),
      annual_interest_rate: Lending::Format.percent(quote.product.annual_interest_rate)
    }
  end

  def quote_params
    @quote_params ||= params.require(:quote).permit(:product_code, :loan_term, :purchase_price, :repair_budget, :arv)
  end

  def preview_error_message(error)
    return 'That is not a product we offer.' if error.is_a?(Lending::Catalog::UnknownProduct)

    'We could not price that. Check the figures and try again.'
  end

  def render_parameter_missing(exception)
    render json: { errors: [exception.message] }, status: :bad_request
  end
end
