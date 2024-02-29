# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lending::Catalog do
  describe 'the shipped catalog' do
    it 'offers the three products the form advertises' do
      expect(described_class.codes).to contain_exactly('fix_and_flip', 'bridge', 'new_construction')
    end

    it 'defaults to the flagged product' do
      expect(described_class.default_code).to eq('fix_and_flip')
      expect(described_class.default.name).to eq('Fix & Flip')
    end

    it 'builds every entry into a Product without raising' do
      expect(described_class.all).to all(be_a(Lending::Product))
    end

    it 'raises a useful error for an unknown code' do
      expect { described_class.fetch('mortgage') }
        .to raise_error(described_class::UnknownProduct, /mortgage.*fix_and_flip/m)
    end

    it 'returns nil rather than raising from #find' do
      expect(described_class.find('mortgage')).to be_nil
    end
  end

  # This is the extension seam: a new product must be a file change only.
  describe 'adding a product' do
    let(:yaml) do
      <<~YAML
        heavy_rehab:
          name: "Heavy Rehab"
          description: "Down to the studs."
          purchase_price_ltv: "0.85"
          arv_ltv: "0.68"
          annual_interest_rate: "0.1425"
          min_term_months: 6
          max_term_months: 18
      YAML
    end

    let(:catalog_path) do
      path = Rails.root.join('tmp', "lending-products-#{SecureRandom.hex(4)}.yml")
      path.write(yaml)
      path
    end

    # Runs after the suite-wide hook that points the catalog at the real file.
    before { described_class.configure(path: catalog_path) }
    after { FileUtils.rm_f(catalog_path) }

    it 'exposes the new product with no code change' do
      expect(described_class.codes).to eq(['heavy_rehab'])
      expect(described_class.fetch('heavy_rehab').arv_ltv).to eq(BigDecimal('0.68'))
    end

    it 'prices a quote against it immediately' do
      quote = build_quote(product: described_class.fetch('heavy_rehab'),
                          purchase_price: 200_000, arv: 400_000, term_months: 6)

      expect(quote.purchase_price_cap).to eq(BigDecimal('170000')) # 200,000 x 0.85
      expect(quote.arv_cap).to eq(BigDecimal('272000'))            # 400,000 x 0.68
      expect(quote.max_fundable_amount).to eq(BigDecimal('170000'))
    end

    it 'falls back to the only product when none is flagged default' do
      expect(described_class.default_code).to eq('heavy_rehab')
    end
  end

  it 'refuses to be used before it is configured' do
    described_class.instance_variable_set(:@path, nil)
    described_class.reset!

    expect { described_class.codes }.to raise_error(described_class::NotConfigured)
  end
end
