# frozen_string_literal: true

# The loan request form is public and unauthenticated, and every successful
# submission spawns a wkhtmltopdf process and sends an email. Throttling it is
# the cheapest protection available for both the queue and our mail reputation.
#
# Limits are generous for a human filling in a seven-step form and tight enough
# that a script cannot fill the queue.
Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

Rack::Attack.throttle('loan_requests/ip', limit: 5, period: 1.minute) do |request|
  request.ip if request.post? && request.path == '/loan_requests'
end

# Quote previews are cheap and fire as the borrower reaches the review step, so
# this only needs to stop a scraper.
Rack::Attack.throttle('quotes/ip', limit: 30, period: 1.minute) do |request|
  request.ip if request.post? && request.path == '/quotes'
end

Rack::Attack.throttled_responder = lambda do |_request|
  [429,
   { 'Content-Type' => 'application/json' },
   [{ errors: ['Too many requests. Please wait a moment and try again.'] }.to_json]]
end

# Off in the test environment by default; the throttle spec switches it on for
# the examples that assert it.
Rack::Attack.enabled = !Rails.env.test?
