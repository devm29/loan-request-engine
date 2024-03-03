# frozen_string_literal: true

# Everything the multi-step form needs that is not a lending figure: the
# step labels, the progress markup, and the per-product term windows.
module LoanRequestHelper
  # The single source of truth for the form's steps. The progress indicator,
  # the panels in app/views/loan_requests/new.html.erb and the Stimulus
  # controller all count steps; this constant keeps them from drifting apart.
  STEPS = %w[Property Term Price Repairs Value You Review].freeze

  def form_steps
    STEPS
  end

  # Term windows are product-specific, so the form needs them client-side to
  # bound the term input and explain the bound. The figures themselves are
  # still only ever calculated on the server.
  def product_term_windows
    Lending::Catalog.all.each_with_object({}) do |product, acc|
      acc[product.code] = {
        name: product.name,
        min: product.min_term_months,
        max: product.max_term_months
      }
    end
  end

  def render_steps(total_steps = STEPS.length)
    safe_join(
      STEPS.first(total_steps).each_with_index.map do |label, index|
        content_tag(:span, label,
                    class: "step-#{index + 1} text-[11px] font-medium uppercase tracking-wide " \
                           'text-slate-400 transition-colors',
                    data: { step_index: index + 1 })
      end
    )
  end
end
