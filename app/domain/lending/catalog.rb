# frozen_string_literal: true

require 'yaml'

module Lending
  # The registry of lending products.
  #
  # This is the application's extension seam. A new loan product — a different
  # LTV pair, rate or term window — is a new entry in the YAML file the catalog
  # is pointed at. No controller, job, view or calculator knows a product code.
  class Catalog
    class UnknownProduct < KeyError; end
    class NotConfigured < StandardError; end

    class << self
      attr_writer :path

      def configure(path:)
        @path = path.to_s
        reset!
      end

      def path
        @path || raise(NotConfigured, 'Lending::Catalog.configure(path:) has not been called')
      end

      def reset!
        @instance = nil
      end

      def instance
        @instance ||= from_file(path)
      end

      def from_file(path)
        definitions = YAML.safe_load_file(path) || {}
        new(definitions)
      end

      # Explicitly forwarded rather than delegated: nothing under app/domain
      # depends on Rails or ActiveSupport.
      %i[all codes fetch find default default_code size].each do |name|
        define_method(name) { |*args| instance.public_send(name, *args) }
      end
    end

    def initialize(definitions)
      @products = definitions.each_with_object({}) do |(code, attributes), acc|
        acc[code.to_s] = Product.new(code, attributes)
      end.freeze
      @default_code = pick_default(definitions)
      freeze
    end

    def all
      @products.values
    end

    def codes
      @products.keys
    end

    def size
      @products.size
    end

    def find(code)
      @products[code.to_s]
    end

    def fetch(code)
      find(code) || raise(UnknownProduct, "unknown lending product #{code.inspect}; known: #{codes.join(', ')}")
    end

    attr_reader :default_code

    def default
      fetch(@default_code)
    end

    private

    def pick_default(definitions)
      flagged = definitions.find { |_code, attributes| attributes.transform_keys(&:to_s)['default'] }
      (flagged&.first || definitions.keys.first).to_s
    end
  end
end
