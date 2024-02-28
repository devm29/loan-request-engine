# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters += %i[
  passw secret token _key crypt salt certificate otp ssn
]

# Loan requests carry applicant PII; keep it out of the request logs.
Rails.application.config.filter_parameters += %i[
  first_name last_name email phone address
]
