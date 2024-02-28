# frozen_string_literal: true

require 'rails_helper'

# The controllers reach the browser as ES modules through the import map, with
# no build step. These examples render the real layout and fetch the pinned
# files through the asset pipeline, so a broken pin fails here rather than as a
# silent dead form in the browser.
RSpec.describe 'JavaScript delivery' do
  let(:importmap) do
    get root_path
    JSON.parse(response.body[%r{<script type="importmap"[^>]*>(.*?)</script>}m, 1])['imports']
  end

  it 'pins Stimulus and every controller the views reference' do
    expect(importmap.keys).to include(
      'application', '@hotwired/stimulus',
      'controllers/flash_controller',
      'controllers/loan_request_form_controller',
      'controllers/term_sheet_controller'
    )
  end

  it 'serves each pinned module' do
    importmap.each_value do |path|
      get path
      expect(response).to have_http_status(:ok), "#{path} answered #{response.status}"
    end
  end

  it 'registers every controller under the name the views use' do
    index = Rails.root.join('app/javascript/controllers/index.js').read
    %w[flash loan-request-form term-sheet].each do |name|
      expect(index).to include("application.register(\"#{name}\",")
    end
  end
end
