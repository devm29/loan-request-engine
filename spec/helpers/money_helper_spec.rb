# frozen_string_literal: true

require 'rails_helper'

# Views format money through the domain, so the figure on screen, the figure on
# the PDF and the allow-list the numeric guard checks are one renderer.
RSpec.describe MoneyHelper, type: :helper do
  it 'formats money exactly as the domain does' do
    expect(helper.money(BigDecimal('193500'))).to eq(Lending::Format.currency(BigDecimal('193500')))
    expect(helper.money(BigDecimal('193500'))).to eq('$193,500.00')
  end

  it 'formats percentages exactly as the domain does' do
    expect(helper.percentage(BigDecimal('0.115'))).to eq('11.5%')
  end

  it 'formats terms exactly as the domain does' do
    expect(helper.months(1)).to eq('1 month')
  end
end
