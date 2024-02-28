# frozen_string_literal: true

module Lending
  # What a borrower is told about their quote, alongside the numbers.
  #
  # `facts` are the rendered figures the explanation is allowed to mention.
  # `bullets` are generated deterministically from the quote and are the only
  # place a number appears. `narrative` is prose only; it may be written by a
  # language model, which is why it is kept separate from - and never the
  # source of - any figure.
  Explanation = Struct.new(:headline, :bullets, :narrative, :facts, :source, keyword_init: true) do
    def generated?
      source.to_s == 'claude'
    end

    def to_h
      { headline: headline, bullets: bullets, narrative: narrative, source: source.to_s }
    end
  end
end
