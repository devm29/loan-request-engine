# wicked_pdf 2.8 builds its config with OpenStruct but never requires it; it
# only worked while some other gem happened to load ostruct first.
require 'ostruct'

WickedPdf.configure do |config|
  # Set WKHTMLTOPDF_PATH to point at a system binary; otherwise use the one
  # shipped by the wkhtmltopdf-binary gem (development only). Hardcoding
  # /usr/local/bin/wkhtmltopdf breaks on any machine that does not happen to
  # have it there.
  detected_exe_path = ENV['WKHTMLTOPDF_PATH'].presence || begin
    Gem.bin_path('wkhtmltopdf-binary', 'wkhtmltopdf')
  rescue StandardError
    nil
  end
  config.exe_path = detected_exe_path if detected_exe_path
  config.enable_local_file_access = true
end
