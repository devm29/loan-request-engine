# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module Lending
  module Explainers
    # Writes the prose half of an explanation with the Claude Messages API.
    #
    # Deliberately narrow: it is handed the already-computed figures and asked
    # for two or three sentences of plain English about *which cap binds and
    # what the borrower can do about it*. It is not asked to compute anything,
    # it is not given the raw inputs to compute from, and whatever it returns
    # is put through Lending::NumericGuard before a borrower sees it. The
    # deterministic bullets carry every number either way.
    #
    # Raw Net::HTTP rather than the official `anthropic` gem: that gem declares
    # `required_ruby_version >= 3.2.0` and this application is pinned to Ruby
    # 3.1.3 for Rails 6.1. One endpoint, no streaming, no tools - the SDK would
    # not earn a Ruby upgrade here, and an upgrade is not what this change is.
    #
    # Server-side refusal fallbacks are deliberately not used either. The
    # fallback that matters here is not a different model, it is the
    # deterministic explainer: a substitute model's prose would still have to
    # clear Lending::NumericGuard, and Rules is guaranteed to.
    module Claude
      ENDPOINT = 'https://api.anthropic.com/v1/messages'
      API_VERSION = '2023-06-01'
      DEFAULT_MODEL = 'claude-opus-5'
      DEFAULT_TIMEOUT = 10
      MAX_TOKENS = 2048

      class ConfigurationError < StandardError; end

      SYSTEM_PROMPT = <<~PROMPT
        You write one short paragraph for a hard-money real estate lender's term sheet.

        You are given figures that have already been calculated. Your job is to explain,
        in plain English, which lending cap limited this loan and what the borrower could
        realistically change. You are not a calculator and not an underwriter.

        Rules:
        - Do not state, repeat, restate or derive any number, amount, percentage or
          duration. Not one digit. The figures are shown to the borrower separately.
        - Write 2 to 3 sentences of plain prose. No markdown, no bullet points, no headings.
        - Address the borrower as "you". Be direct and factual, never promotional.
        - Do not promise approval, funding or terms. This is an estimate.
      PROMPT

      module_function

      # @return [String, nil] prose, or nil when not configured
      def narrative(quote, facts: [])
        key = api_key
        raise ConfigurationError, 'ANTHROPIC_API_KEY is not set' if key.to_s.strip.empty?

        body = request_body(quote, facts)
        response = post(key, body)
        extract_text(response)
      end

      def request_body(quote, facts)
        {
          model: model,
          max_tokens: MAX_TOKENS,
          # Low effort: this is a two-sentence explanation, not a reasoning task.
          output_config: { effort: 'low' },
          system: SYSTEM_PROMPT,
          messages: [{ role: 'user', content: user_prompt(quote, facts) }]
        }
      end

      def user_prompt(quote, facts)
        <<~TEXT
          Product: #{quote.product.name} - #{quote.product.description}
          The binding cap on this request was: #{binding_label(quote.binding_constraint)}
          Figures already shown to the borrower (do not repeat them): #{Array(facts).join(', ')}

          Explain which cap limited the loan and what the borrower could change.
        TEXT
      end

      def binding_label(constraint)
        case constraint
        when :purchase_price then 'the loan-to-cost cap on the purchase price'
        when :arv then 'the loan-to-value cap on the after-repair value'
        else 'both caps equally'
        end
      end

      def post(key, body)
        uri = URI(ENDPOINT)
        response = http_client(uri).request(signed_request(uri, key, body))
        raise "Claude API returned #{response.code}: #{truncate(response.body)}" unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)
      end

      def signed_request(uri, key, body)
        request = Net::HTTP::Post.new(uri)
        request['x-api-key'] = key
        request['anthropic-version'] = API_VERSION
        request['content-type'] = 'application/json'
        request.body = JSON.generate(body)
        request
      end

      # Both timeouts are set: a hung connection must not hold a Sidekiq thread
      # open long past the point the job would otherwise have finished.
      def http_client(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = timeout
        http.read_timeout = timeout
        http
      end

      # Error bodies reach the log; keep them short and out of the way.
      def truncate(body, limit = 300)
        body.to_s[0, limit]
      end

      # A refusal arrives as HTTP 200 with stop_reason "refusal" and a category
      # in stop_details; treat it as "no narrative" and let the caller fall back
      # to the deterministic explainer.
      def extract_text(payload)
        if payload['stop_reason'] == 'refusal'
          Rails.logger.info(
            "Lending::Explainers::Claude: refused (#{payload.dig('stop_details', 'category') || 'uncategorised'})"
          )
          return nil
        end

        Array(payload['content'])
          .select { |block| block['type'] == 'text' }
          .pluck('text')
          .join(' ')
          .strip
          .presence
      end

      def api_key
        ENV.fetch('ANTHROPIC_API_KEY', nil)
      end

      def model
        ENV.fetch('ANTHROPIC_MODEL', DEFAULT_MODEL)
      end

      def timeout
        Integer(ENV.fetch('ANTHROPIC_TIMEOUT_SECONDS', DEFAULT_TIMEOUT))
      end
    end
  end
end
