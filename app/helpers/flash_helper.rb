# frozen_string_literal: true

# Maps a flash key to the Tailwind classes that style its banner.
module FlashHelper
  FLASH_CLASSES = {
    notice: 'bg-green-50 border-green-300 text-green-900',
    alert: 'bg-red-50 border-red-300 text-red-900'
  }.freeze
  DEFAULT_FLASH_CLASS = 'bg-blue-50 border-blue-300 text-blue-900'

  def flash_class_for(flash_type)
    FLASH_CLASSES.fetch(flash_type.to_sym, DEFAULT_FLASH_CLASS)
  end
end
