# frozen_string_literal: true

module Lending
  # A lending product: the policy caps, rate and term limits that a quote is
  # calculated against. Immutable, and built only from exact decimal values.
  #
  # Products are data (config/lending_products.yml), not code. Adding one is a
  # new entry in that file; nothing here or in Lending::Quote changes.
  class Product
    REQUIRED_KEYS = %w[name purchase_price_ltv arv_ltv annual_interest_rate
                       min_term_months max_term_months].freeze

    class InvalidDefinition < StandardError; end

    attr_reader :code, :name, :description, :purchase_price_ltv, :arv_ltv,
                :annual_interest_rate, :min_term_months, :max_term_months

    # @param code [String] stable identifier persisted on a loan request
    # @param attributes [Hash] the YAML entry for this product
    def initialize(code, attributes)
      definition = attributes.transform_keys(&:to_s)
      missing = REQUIRED_KEYS - definition.keys
      raise InvalidDefinition, "product #{code.inspect} is missing #{missing.join(', ')}" if missing.any?

      @code = code.to_s
      @name = definition.fetch('name').to_s
      @description = definition.fetch('description', '').to_s
      @purchase_price_ltv = rate(code, 'purchase_price_ltv', definition)
      @arv_ltv = rate(code, 'arv_ltv', definition)
      @annual_interest_rate = rate(code, 'annual_interest_rate', definition)
      @min_term_months = Integer(definition.fetch('min_term_months'))
      @max_term_months = Integer(definition.fetch('max_term_months'))
      validate_ranges!
      freeze
    end

    def term_range
      (min_term_months..max_term_months)
    end

    def term_months_valid?(months)
      months.is_a?(Integer) && term_range.cover?(months)
    end

    def to_h
      { code: code, name: name, description: description,
        purchase_price_ltv: purchase_price_ltv, arv_ltv: arv_ltv,
        annual_interest_rate: annual_interest_rate,
        min_term_months: min_term_months, max_term_months: max_term_months }
    end

    private

    # Rates must be written as quoted strings in YAML. An unquoted 0.13 is
    # parsed by Psych as a Float, and a Float rate is exactly the defect this
    # application had before: it is rejected loudly rather than absorbed.
    def rate(code, key, definition)
      raw = definition.fetch(key)
      if raw.is_a?(Float)
        raise InvalidDefinition,
              "product #{code.inspect} defines #{key} as the Float #{raw.inspect}; " \
              'quote it in the YAML ("0.13") so it is read as an exact decimal'
      end

      value = Money.cast(raw)
      raise InvalidDefinition, "product #{code.inspect} has a #{key} outside 0..1" unless (0..1).cover?(value)

      value
    end

    def validate_ranges!
      return if min_term_months.positive? && max_term_months >= min_term_months

      raise InvalidDefinition, "product #{code.inspect} has an impossible term range"
    end
  end
end
