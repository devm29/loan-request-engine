# frozen_string_literal: true

require 'bigdecimal'
require 'bigdecimal/util'

module Lending
  # Money handling for the whole application.
  #
  # Every figure that reaches a borrower is produced here or by {Lending::Quote},
  # and every one of them is a BigDecimal. Binary floats cannot represent 0.9,
  # 0.7 or 0.13 exactly, so a Float that gets anywhere near a rate leaks error
  # into a number somebody is asked to sign. `cast` therefore *refuses* Floats
  # rather than quietly converting one: a Float in the money path is a bug at
  # the place it was introduced, not here.
  module Money
    CENT = BigDecimal('0.01')
    ZERO = BigDecimal('0')

    class FloatError < ArgumentError; end

    module_function

    # Coerce a value into an exact BigDecimal.
    #
    # Integers, Rationals, BigDecimals and decimal strings are exact and are
    # accepted. Floats are rejected.
    def cast(value)
      case value
      when BigDecimal then value
      when Integer, String then BigDecimal(value)
      when Rational then BigDecimal(value, Float::DIG + 1)
      when Float
        raise FloatError, "refusing to build money from the Float #{value.inspect}; " \
                          'pass an Integer, a decimal String or a BigDecimal'
      when nil then raise ArgumentError, 'money value is nil'
      else
        raise ArgumentError, "cannot build money from #{value.class}"
      end
    end

    # Round half-up to the cent. Used for charges we compute (interest), where
    # the fair thing is to round to the nearest cent.
    def round_to_cent(value)
      cast(value).round(2)
    end

    # Round DOWN to the cent - never up, for any input. Used for every policy
    # cap, so that a rounding step can never push a loan amount above the cap
    # it was derived from: rounding half-up would let 0.9 x purchase_price come
    # back a half-cent *over* 90%. The direction is towards negative infinity,
    # not towards zero; money caps are non-negative, so the two coincide here,
    # and where they do not, down is the safe one.
    def floor_to_cent(value)
      cast(value).floor(2)
    end
  end
end
