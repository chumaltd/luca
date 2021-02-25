# frozen_string_literal: true

require 'luca_deal/invoice'

module LucaDeal #:nodoc:
  # Invoice compatible transactions for other payment methods.
  #
  class NoInvoice < Invoice
    @dirname = 'no_invoices'

    def monthly_invoice
      super('other_payments')
    end

    # Override not to send mail to customer.
    #
    def deliver_mail(attachment_type = nil, mode: nil)
    end
  end
end
