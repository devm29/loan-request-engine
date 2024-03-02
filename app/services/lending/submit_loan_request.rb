# frozen_string_literal: true

module Lending
  # The create use case, out of the controller.
  #
  # Two things make it worth its own object. First, idempotency: a resubmission
  # of an identical request returns the original record instead of creating a
  # second one and sending a second email. Second, the enqueue is not allowed
  # to fail the request - the borrower's data is already safely committed, and
  # a Redis outage should not turn a successful submission into a 500. The
  # request is left undelivered and `rake lending:requeue_stalled` picks it up.
  class SubmitLoanRequest
    Result = Struct.new(:loan_request, :status, keyword_init: true) do
      def success?
        %i[created duplicate].include?(status)
      end

      def duplicate?
        status == :duplicate
      end
    end

    def self.call(attributes)
      new(attributes).call
    end

    def initialize(attributes)
      @attributes = attributes
    end

    def call
      candidate = LoanRequest.new(@attributes)
      existing = existing_for(candidate)
      return Result.new(loan_request: existing, status: :duplicate) if existing

      if candidate.save
        enqueue(candidate)
        Result.new(loan_request: candidate, status: :created)
      else
        Result.new(loan_request: candidate, status: :invalid)
      end
    rescue ActiveRecord::RecordNotUnique
      # Two identical submissions raced past the read above; the unique index
      # on request_fingerprint is the authority.
      duplicate = existing_for(candidate)
      return Result.new(loan_request: duplicate, status: :duplicate) if duplicate

      raise
    end

    private

    def existing_for(candidate)
      candidate.validate
      fingerprint = candidate.request_fingerprint
      return nil if fingerprint.blank?

      LoanRequest.find_by(request_fingerprint: fingerprint)
    end

    def enqueue(loan_request)
      LoanProcessorJob.perform_async(loan_request.id)
    rescue StandardError => e
      Rails.logger.error(
        "SubmitLoanRequest: could not enqueue LoanProcessorJob for #{loan_request.id} " \
        "(#{e.class}: #{e.message}); the request is saved and will be requeued"
      )
    end
  end
end
