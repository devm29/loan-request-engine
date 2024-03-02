# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HealthController, type: :controller do
  it 'reports ok when the database answers' do
    get :show, format: :json

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body['status']).to eq('ok')
    expect(body['products']).to eq(Lending::Catalog.size)
  end

  # A process that booted but lost its database must report unhealthy, or the
  # container healthcheck is worthless.
  it 'reports unavailable when the database does not' do
    allow(ActiveRecord::Base).to receive(:connection).and_raise(ActiveRecord::ConnectionNotEstablished)

    get :show, format: :json

    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body['status']).to eq('error')
  end

  it 'does not leak the exception message' do
    allow(ActiveRecord::Base).to receive(:connection)
      .and_raise(ActiveRecord::ConnectionNotEstablished, 'password=hunter2 refused')

    get :show, format: :json

    expect(response.body).not_to include('hunter2')
  end
end
