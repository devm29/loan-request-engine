# frozen_string_literal: true

redis_options = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1') }

Sidekiq.configure_server do |config|
  config.redis = redis_options
end

Sidekiq.configure_client do |config|
  config.redis = redis_options
end
