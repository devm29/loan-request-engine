# frozen_string_literal: true

require 'webmock/rspec'

# No test may make a real network call. The Claude explainer is the only thing
# in the application that reaches out, and its spec stubs the endpoint
# explicitly; anything else hitting the network is a bug in the test.
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  # The catalog is a memoised singleton. Reset it around every example so a
  # spec that points it at a fixture cannot leak into the next one.
  config.before do
    Lending::Catalog.configure(path: Rails.root.join('config/lending_products.yml'))
    ENV.delete('ANTHROPIC_API_KEY')
    ENV.delete('LENDING_EXPLAINER')
  end

  config.after { Lending::Catalog.reset! }
end

# Builders for the domain objects the specs need, without a database.
module LendingSpecHelpers
  # Builds a quote without touching the database.
  def build_quote(product: Lending::Catalog.default, purchase_price: 215_000,
                  repair_budget: 48_000, arv: 340_000, term_months: 6)
    Lending::Quote.new(
      product: product, purchase_price: purchase_price,
      repair_budget: repair_budget, arv: arv, term_months: term_months
    )
  end

  def product_with(**overrides)
    Lending::Product.new(
      overrides.delete(:code) || 'test_product',
      {
        'name' => 'Test Product', 'description' => 'For specs',
        'purchase_price_ltv' => '0.90', 'arv_ltv' => '0.70',
        'annual_interest_rate' => '0.13',
        'min_term_months' => 1, 'max_term_months' => 12
      }.merge(overrides.transform_keys(&:to_s))
    )
  end
end

RSpec.configure { |config| config.include LendingSpecHelpers }
