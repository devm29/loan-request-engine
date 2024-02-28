# WickedPDF Global Configuration
#
# Use this to set up shared configuration options for your entire application.
# Any of the configuration options shown here can also be applied to single
# models by passing arguments to the `render :pdf` call.
#
# To learn more, check out the README:
#
# https://github.com/mileszs/wicked_pdf/blob/master/README.md

WickedPdf.configure do |config|
  # Path to the wkhtmltopdf executable: This usually isn't needed if using
  # one of the wkhtmltopdf-binary family of gems.
  # config.exe_path = '/usr/local/bin/wkhtmltopdf',
  #   or
  # config.exe_path = Gem.bin_path('wkhtmltopdf-binary', 'wkhtmltopdf')

  # Needed for wkhtmltopdf 0.12.6+ to use many wicked_pdf asset helpers
  # config.enable_local_file_access = true,

  # Layout file to be used for all PDFs
  # (but can be overridden in `render :pdf` calls)
  # config.layout = 'pdf.html',

  # Using wkhtmltopdf without an X server can be achieved by enabling the
  # 'use_xvfb' flag. This will wrap all wkhtmltopdf commands around the
  # 'xvfb-run' command, in order to simulate an X server.
  #
  # config.use_xvfb = true,
  # Path to the wkhtmltopdf executable. Set WKHTMLTOPDF_PATH to point at a
  # system binary; otherwise use the one shipped by the wkhtmltopdf-binary gem.
  # Hardcoding /usr/local/bin/wkhtmltopdf breaks on any machine that does not
  # happen to have it there (Apple Silicon, Linux containers, CI).
  detected_exe_path = ENV['WKHTMLTOPDF_PATH'].presence || begin
    Gem.bin_path('wkhtmltopdf-binary', 'wkhtmltopdf')
  rescue StandardError
    nil
  end
  config.exe_path = detected_exe_path if detected_exe_path
  config.enable_local_file_access = true
end
