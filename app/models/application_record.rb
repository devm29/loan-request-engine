# frozen_string_literal: true

# Base class for the application's models.
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end
