# frozen_string_literal: true

require 'set'

module Lending
  # Refuses to show a borrower a number that the lending code did not compute.
  #
  # A language model may be asked to explain a quote; it is never allowed to
  # state one. The guard extracts every numeric token from generated prose and
  # checks each against the rendered figures of the quote it is explaining.
  # One unrecognised token discards the whole narrative and the deterministic
  # one is used instead - there is no partial acceptance and no repair step,
  # because a figure that is nearly right is worse than one that is absent.
  #
  # A token's unit is part of its identity: "70%" and "$70" are different
  # claims and neither vouches for the other.
  module NumericGuard
    TOKEN = /\$\s?\d[\d,]*(?:\.\d+)?|\d[\d,]*(?:\.\d+)?\s?%|\d[\d,]*(?:\.\d+)?/

    module_function

    # @return [Array<String>] the tokens in `text` that `facts` does not vouch for
    def unvouched_tokens(text, facts:)
      allowed = key_set(facts)
      text.to_s.scan(TOKEN).reject { |token| allowed.include?(key(token)) }
    end

    def verify(text, facts:)
      unvouched_tokens(text, facts: facts).empty?
    end

    def key_set(facts)
      Array(facts).flat_map { |fact| fact.to_s.scan(TOKEN) }.to_set { |token| key(token) }
    end

    # "$180,000.00" -> "currency:180000"; "11.5 %" -> "percent:11.5"; "6" -> "bare:6"
    def key(token)
      text = token.to_s
      "#{unit_of(text)}:#{canonical_digits(text)}"
    end

    def unit_of(text)
      return 'currency' if text.include?('$')
      return 'percent' if text.include?('%')

      'bare'
    end

    # Compared as exact decimals, never as Floats: "$180,000.00" and "$180,000"
    # are the same claim and must produce the same key.
    def canonical_digits(text)
      BigDecimal(text.delete('$%, ').strip).to_s('F').sub(/(\.\d*?)0+\z/, '\1').delete_suffix('.')
    rescue ArgumentError
      "unparsable(#{text})"
    end
  end
end
