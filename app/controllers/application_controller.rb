# frozen_string_literal: true

# Base controller. Every action in this application is public and
# unauthenticated; rate limiting lives in config/initializers/rack_attack.rb.
class ApplicationController < ActionController::Base
end
