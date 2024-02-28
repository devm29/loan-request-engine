# frozen_string_literal: true

namespace :lending do
  desc 'Re-enqueue loan requests whose term sheet was never delivered'
  task requeue_stalled: :environment do
    older_than = Integer(ENV.fetch('STALLED_AFTER_MINUTES', 15)).minutes.ago
    batch_size = Integer(ENV.fetch('BATCH_SIZE', 500))

    # Uses index_loan_requests_undelivered. `find_each` keeps the working set
    # bounded: a backlog after an outage can be large, and loading it into one
    # array is how a recovery task takes the box down with it.
    scope = LoanRequest.undelivered.where(created_at: ..older_than)

    count = 0
    scope.find_each(batch_size: batch_size) do |loan_request|
      LoanProcessorJob.perform_async(loan_request.id)
      count += 1
    end

    puts "Re-enqueued #{count} stalled loan request(s) created before #{older_than.iso8601}."
  end

  desc 'Print the product catalog as the application reads it'
  task products: :environment do
    Lending::Catalog.all.each do |product|
      puts format(
        '%<code>-18s %<name>-20s LTC %<ltc>-6s LTV %<ltv>-6s rate %<rate>-7s term %<min>d-%<max>d months',
        code: product.code, name: product.name,
        ltc: Lending::Format.percent(product.purchase_price_ltv),
        ltv: Lending::Format.percent(product.arv_ltv),
        rate: Lending::Format.percent(product.annual_interest_rate),
        min: product.min_term_months, max: product.max_term_months
      )
    end
  end
end
