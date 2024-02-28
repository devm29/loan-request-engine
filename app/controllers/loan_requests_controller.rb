# frozen_string_literal: true

# The public form and its create endpoint.
#
# The controller does three things: permit parameters, hand them to
# Lending::SubmitLoanRequest, and render the outcome. Validation lives in the
# model, idempotency and enqueueing in the service, arithmetic in the domain.
class LoanRequestsController < ApplicationController
  rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

  def new
    @loan_request = LoanRequest.new(product_code: Lending::Catalog.default_code)
    @products = Lending::Catalog.all
  end

  def create
    result = Lending::SubmitLoanRequest.call(loan_request_params)
    @loan_request = result.loan_request

    if result.success?
      respond_success(result)
    else
      respond_failure
    end
  end

  private

  def respond_success(result)
    destination = term_sheet_path(@loan_request.reference)
    notice = if result.duplicate?
               'We already have this request. Here is the term sheet you asked for.'
             else
               'Loan request was successfully created.'
             end

    respond_to do |format|
      flash.now[:notice] = notice
      format.html { redirect_to destination }
      format.json { render json: { redirect_url: destination, reference: @loan_request.reference }, status: :ok }
    end
  end

  def respond_failure
    respond_to do |format|
      flash.now[:alert] = 'Loan Request could not be saved.'
      format.html { redirect_to root_path }
      format.json do
        render json: { errors: @loan_request.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end

  def loan_request_params
    params.require(:loan_request).permit(:address, :loan_term, :purchase_price, :repair_budget, :arv, :first_name,
                                         :last_name, :email, :phone, :product_code)
  end

  # Return 400 Bad Request when required params are missing (e.g. JSON without loan_request key).
  def handle_parameter_missing(exception)
    respond_to do |format|
      format.html { redirect_to root_path, alert: 'Invalid request.' }
      format.json do
        render json: { errors: [exception.message] }, status: :bad_request
      end
    end
  end
end
