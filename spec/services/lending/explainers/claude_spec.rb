# frozen_string_literal: true

require 'rails_helper'

# Every example here stubs the HTTP endpoint. WebMock is configured in
# spec/support/lending.rb to refuse real connections, so no test can spend
# money even by accident.
RSpec.describe Lending::Explainers::Claude do
  let(:quote) { build_quote(purchase_price: 215_000, repair_budget: 48_000, arv: 340_000, term_months: 6) }
  let(:facts) { Lending::Explainers::Rules.facts(quote) }

  def stub_messages(body:, status: 200)
    stub_request(:post, described_class::ENDPOINT)
      .to_return(status: status, body: body.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  context 'without an API key' do
    it 'raises a configuration error rather than calling out' do
      expect { described_class.narrative(quote, facts: facts) }
        .to raise_error(described_class::ConfigurationError, /ANTHROPIC_API_KEY/)
    end
  end

  context 'with an API key' do
    before { ENV['ANTHROPIC_API_KEY'] = 'sk-ant-test' }

    it 'returns the prose from the response' do
      stub_messages(body: { content: [{ type: 'text', text: 'The purchase price is the binding limit.' }] })

      expect(described_class.narrative(quote, facts: facts)).to eq('The purchase price is the binding limit.')
    end

    it 'authenticates with the key and the API version header' do
      request = stub_messages(body: { content: [{ type: 'text', text: 'ok' }] })
      described_class.narrative(quote, facts: facts)

      expect(request.with(headers: { 'x-api-key' => 'sk-ant-test',
                                     'anthropic-version' => described_class::API_VERSION })).to have_been_made
    end

    it 'instructs the model not to state a figure' do
      stub_messages(body: { content: [{ type: 'text', text: 'ok' }] })
      described_class.narrative(quote, facts: facts)

      expect(a_request(:post, described_class::ENDPOINT).with do |req|
        JSON.parse(req.body)['system'].include?('Do not state, repeat, restate or derive any number')
      end).to have_been_made
    end

    it 'sends the already-computed figures, never the raw inputs to compute from' do
      stub_messages(body: { content: [{ type: 'text', text: 'ok' }] })
      described_class.narrative(quote, facts: facts)

      expect(a_request(:post, described_class::ENDPOINT).with do |req|
        prompt = JSON.parse(req.body)['messages'].first['content']
        prompt.include?('do not repeat them') && prompt.include?('$193,500.00')
      end).to have_been_made
    end

    it 'uses the model named in the environment' do
      ENV['ANTHROPIC_MODEL'] = 'claude-haiku-4-5'
      stub_messages(body: { content: [{ type: 'text', text: 'ok' }] })
      described_class.narrative(quote, facts: facts)

      expect(a_request(:post, described_class::ENDPOINT)
        .with { |req| JSON.parse(req.body)['model'] == 'claude-haiku-4-5' }).to have_been_made
    ensure
      ENV.delete('ANTHROPIC_MODEL')
    end

    it 'treats a refusal as no narrative' do
      stub_messages(body: { stop_reason: 'refusal', content: [] })

      expect(described_class.narrative(quote, facts: facts)).to be_nil
    end

    it 'treats an empty response as no narrative' do
      stub_messages(body: { content: [] })

      expect(described_class.narrative(quote, facts: facts)).to be_nil
    end

    it 'raises on an HTTP error so the explainer can fall back' do
      stub_messages(body: { error: { message: 'overloaded' } }, status: 529)

      expect { described_class.narrative(quote, facts: facts) }.to raise_error(/529/)
    end

    it 'joins multiple text blocks' do
      stub_messages(body: { content: [{ type: 'text', text: 'One.' },
                                      { type: 'thinking', thinking: 'ignored' },
                                      { type: 'text', text: 'Two.' }] })

      expect(described_class.narrative(quote, facts: facts)).to eq('One. Two.')
    end
  end

  describe 'end to end through the explainer' do
    before { ENV['ANTHROPIC_API_KEY'] = 'sk-ant-test' }

    it 'uses a clean narrative and keeps the deterministic figures' do
      stub_messages(body: { content: [{ type: 'text',
                                        text: 'Your purchase price is the binding limit here, not the exit value.' }] })

      explanation = Lending::Explainer.call(quote)

      expect(explanation.source).to eq(:claude)
      expect(explanation.narrative).to include('binding limit')
      expect(explanation.headline).to include('$193,500.00')
    end

    it 'discards a narrative that states a number the engine did not compute' do
      stub_messages(body: { content: [{ type: 'text', text: 'You could borrow $250,000 on this.' }] })

      explanation = Lending::Explainer.call(quote)

      expect(explanation.source).to eq(:rules)
      expect(explanation.narrative).not_to include('250,000')
    end

    it 'falls back to the deterministic explainer when the API is down' do
      stub_request(:post, described_class::ENDPOINT).to_timeout

      expect(Lending::Explainer.call(quote).source).to eq(:rules)
    end
  end
end
