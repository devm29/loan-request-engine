# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LoanRequestHelper, type: :helper do
  describe '#render_steps' do
    it 'renders one labelled span per step' do
      spans = Nokogiri::HTML.fragment(helper.render_steps).css('span')

      expect(spans.size).to eq(described_class::STEPS.length)
      expect(spans.map(&:text)).to eq(described_class::STEPS)
    end

    it 'tags each span with its index so the Stimulus controller can highlight it' do
      html = Nokogiri::HTML.fragment(helper.render_steps)

      expect(html.css('span').map { |span| span['data-step-index'] }).to eq(%w[1 2 3 4 5 6 7])
    end

    it 'honours an explicit step count' do
      expect(Nokogiri::HTML.fragment(helper.render_steps(3)).css('span').size).to eq(3)
    end

    it 'returns markup that is safe to render' do
      expect(helper.render_steps).to be_html_safe
    end

    # The progress bar, the panels and the Stimulus controller all count steps.
    it 'matches the number of step panels in the form' do
      form = Rails.root.join('app/views/loan_requests/new.html.erb').read

      expect(form.scan('data-loan-request-form-target="step"').size).to eq(described_class::STEPS.length)
    end
  end

  describe '#product_term_windows' do
    it 'describes every product the form offers' do
      windows = helper.product_term_windows

      expect(windows.keys).to match_array(Lending::Catalog.codes)
      expect(windows['fix_and_flip']).to eq(name: 'Fix & Flip', min: 1, max: 12)
    end

    it 'serialises to JSON the Stimulus values API can read' do
      expect { JSON.parse(helper.product_term_windows.to_json) }.not_to raise_error
    end
  end
end
