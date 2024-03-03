# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FlashHelper, type: :helper do
  describe '#flash_class_for' do
    it 'styles notices green' do
      expect(helper.flash_class_for(:notice)).to include('green')
    end

    it 'styles alerts red' do
      expect(helper.flash_class_for(:alert)).to include('red')
    end

    it 'falls back to the neutral style for unknown flash types' do
      expect(helper.flash_class_for(:something_else)).to include('blue')
    end

    it 'accepts string flash keys, as Rails yields them from the flash hash' do
      expect(helper.flash_class_for('alert')).to eq(helper.flash_class_for(:alert))
    end
  end
end
