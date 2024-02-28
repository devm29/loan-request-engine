# frozen_string_literal: true

# Point the product catalog at its data file.
#
# `to_prepare` rather than a bare initializer: Lending::Catalog is autoloaded,
# and this has to run again after every code reload in development.
Rails.application.config.to_prepare do
  Lending::Catalog.configure(
    path: ENV.fetch('LENDING_PRODUCTS_PATH') { Rails.root.join("config/lending_products.yml") }
  )
end
