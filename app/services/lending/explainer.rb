# frozen_string_literal: true

module Lending
  # Chooses how a quote gets explained, and guarantees an answer.
  #
  # Backends are registered by name, so adding one (a different provider, a
  # per-locale template) is a `register` call. `:rules` is always present and
  # is the fallback for everything: an unset API key, a timeout, an HTTP error,
  # or a narrative that failed Lending::NumericGuard.
  #
  # The deterministic figures are produced first and are never overwritten. A
  # backend may only replace the prose.
  class Explainer
    DEFAULT_BACKEND = :rules

    class << self
      def registry
        @registry ||= { rules: Explainers::Rules, claude: Explainers::Claude }
      end

      def register(name, backend)
        registry[name.to_sym] = backend
      end

      # @return [Lending::Explanation]
      def call(quote, backend: nil)
        baseline = Explainers::Rules.call(quote)
        name = (backend || configured_backend).to_sym
        return baseline if name == :rules

        enrich(baseline, quote, name)
      end

      # `auto` (the default) uses Claude when a key is configured and the
      # deterministic explainer otherwise, so the app runs identically with or
      # without credentials.
      def configured_backend
        configured = ENV.fetch('LENDING_EXPLAINER', 'auto').to_s.downcase
        return configured.to_sym unless configured == 'auto'

        ENV['ANTHROPIC_API_KEY'].to_s.strip.empty? ? :rules : :claude
      end

      private

      def enrich(baseline, quote, name)
        implementation = registry[name]
        return baseline unless implementation.respond_to?(:narrative)

        narrative = implementation.narrative(quote, facts: baseline.facts)
        return baseline if narrative.blank?

        unvouched = NumericGuard.unvouched_tokens(narrative, facts: baseline.facts)
        if unvouched.any?
          Rails.logger.warn("Lending::Explainer: discarding #{name} narrative, unvouched figures #{unvouched.inspect}")
          return baseline
        end

        baseline.narrative = narrative
        baseline.source = name
        baseline
      rescue StandardError => e
        Rails.logger.warn("Lending::Explainer: #{name} backend failed (#{e.class}: #{e.message}); using rules")
        baseline
      end
    end
  end
end
