# frozen_string_literal: true

# Base class for the application's mail. The from address is configuration,
# never a literal, so a deployment can set its own sender.
class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('MAILER_FROM', 'no-reply@example.com')
  layout 'mailer'
end
