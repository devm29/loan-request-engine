# frozen_string_literal: true

# Liveness/readiness probe for the container healthcheck. Touches the database
# so that a booted-but-disconnected process reports unhealthy.
class HealthController < ApplicationController
  def show
    ActiveRecord::Base.connection.execute('SELECT 1')
    render json: { status: 'ok', products: Lending::Catalog.size }
  rescue StandardError => e
    render json: { status: 'error', error: e.class.name }, status: :service_unavailable
  end
end
