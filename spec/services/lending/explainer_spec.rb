# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lending::Explainer do
  let(:quote) { build_quote(purchase_price: 215_000, repair_budget: 48_000, arv: 340_000, term_months: 6) }

  describe 'backend selection' do
    it 'uses the deterministic explainer when no API key is set' do
      expect(described_class.configured_backend).to eq(:rules)
    end

    it 'uses Claude when a key is present' do
      ENV['ANTHROPIC_API_KEY'] = 'sk-ant-test'
      expect(described_class.configured_backend).to eq(:claude)
    end

    it 'honours an explicit LENDING_EXPLAINER setting over the key' do
      ENV['ANTHROPIC_API_KEY'] = 'sk-ant-test'
      ENV['LENDING_EXPLAINER'] = 'rules'
      expect(described_class.configured_backend).to eq(:rules)
    end
  end

  describe '.call' do
    it 'returns a complete explanation with no backend configured' do
      explanation = described_class.call(quote)

      expect(explanation.source).to eq(:rules)
      expect(explanation.headline).to include('$193,500.00')
      expect(explanation.bullets).not_to be_empty
    end

    context 'with a backend that writes acceptable prose' do
      let(:backend) do
        Class.new do
          def self.narrative(_quote, facts:)
            "The purchase price is the limit here, not the exit valuation. #{facts.first} is the ceiling."
          end
        end
      end

      before { described_class.register(:test_backend, backend) }
      after { described_class.registry.delete(:test_backend) }

      it 'replaces the prose and records where it came from' do
        explanation = described_class.call(quote, backend: :test_backend)

        expect(explanation.narrative).to include('The purchase price is the limit here')
        expect(explanation.source).to eq(:test_backend)
      end

      it 'leaves the deterministic bullets untouched' do
        baseline = described_class.call(quote, backend: :rules)
        enriched = described_class.call(quote, backend: :test_backend)

        expect(enriched.bullets).to eq(baseline.bullets)
        expect(enriched.headline).to eq(baseline.headline)
      end
    end

    context 'with a backend that invents a number' do
      let(:backend) do
        Class.new do
          def self.narrative(_quote, facts:)
            'You could probably borrow up to $400,000 against this property.'
          end
        end
      end

      before { described_class.register(:liar, backend) }
      after { described_class.registry.delete(:liar) }

      it 'discards the whole narrative rather than repairing it' do
        explanation = described_class.call(quote, backend: :liar)

        expect(explanation.narrative).not_to include('400,000')
        expect(explanation.source).to eq(:rules)
      end

      it 'says what it rejected' do
        allow(Rails.logger).to receive(:warn)
        described_class.call(quote, backend: :liar)

        expect(Rails.logger).to have_received(:warn).with(/unvouched figures.*400,000/)
      end
    end

    context 'when the backend fails' do
      let(:backend) do
        Class.new do
          def self.narrative(_quote, facts:)
            raise Net::ReadTimeout
          end
        end
      end

      before { described_class.register(:flaky, backend) }
      after { described_class.registry.delete(:flaky) }

      it 'falls back to the deterministic explanation instead of raising' do
        explanation = described_class.call(quote, backend: :flaky)

        expect(explanation.source).to eq(:rules)
        expect(explanation.headline).to include('$193,500.00')
      end
    end

    it 'falls back when the backend returns nothing' do
      empty = Class.new { def self.narrative(_quote, facts:) = '' }
      described_class.register(:empty, empty)

      expect(described_class.call(quote, backend: :empty).source).to eq(:rules)
    ensure
      described_class.registry.delete(:empty)
    end

    it 'falls back when the named backend is not registered' do
      expect(described_class.call(quote, backend: :nonexistent).source).to eq(:rules)
    end
  end
end
