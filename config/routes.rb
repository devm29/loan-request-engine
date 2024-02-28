# frozen_string_literal: true

Rails.application.routes.draw do
  root 'loan_requests#new'

  resources :loan_requests, only: %i[new create]

  # Server-computed quote preview for the review step of the form. The browser
  # never calculates a figure.
  resources :quotes, only: :create

  # Term sheets are addressed by an unguessable reference, never by the
  # sequential id of a record holding applicant PII.
  get 'term-sheets/:reference', to: 'term_sheets#show', as: :term_sheet
  get 'term-sheets/:reference/status', to: 'term_sheets#status', as: :term_sheet_status
  get 'term-sheets/:reference/document.pdf', to: 'term_sheets#document', as: :term_sheet_document

  # Container healthcheck.
  get 'up', to: 'health#show'
end
