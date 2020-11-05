require 'luca_deal/version'

require 'mail'
require 'yaml'
require 'pathname'
require 'bigdecimal'
require 'luca_support/config'
require 'luca_support/mail'
require 'luca_deal'

module LucaDeal
  class Fee < LucaRecord::Base
    @dirname = 'fees'

    def initialize(date = nil)
      @date = issue_date(date)
      @config = load_config('config.yml')
    end

    # calculate fee, based on invoices
    #
    def monthly_fee
      LucaDeal::Contract.asof(@date.year, @date.month, @date.day) do |contract|
        next if contract.dig('terms', 'category') != 'sales_fee'

        @rate = { 'default' => BigDecimal(contract.dig('rate', 'default')) }
        @rate['initial'] = contract.dig('rate', 'initial') ? BigDecimal(contract.dig('rate', 'initial')) : @rate['default']

        LucaDeal::Invoice.asof(@date.year, @date.month) do |invoice|
          next if invoice.dig('sales_fee', 'id') != contract['id']
          next if duplicated_contract? invoice['contract_id']

          fee = invoice.dup
          fee['invoice'] = {}.tap do |f_invoice|
            %w[id contract_id issue_date due_date].each do |i|
              f_invoice[i] = invoice[i]
              fee.delete i
            end
          end
          fee['id'] = issue_random_id
          fee['customer'].delete('to')
          fee['sales_fee'].merge! subtotal(fee['items'])
          gen_fee!(fee)
        end
      end
    end

    def get_customer(id)
      {}.tap do |res|
        LucaDeal::Customer.find(id) do |dat|
          customer = parse_current(dat)
          res['id'] = customer['id']
          res['name'] = customer.dig('name')
          res['address'] = customer.dig('address')
          res['address2'] = customer.dig('address2')
          res['to'] = customer.dig('contacts').map { |h| take_current(h, 'mail') }.compact
        end
      end
    end

    def gen_fee!(fee)
      id = fee.dig('invoice', 'contract_id')
      self.class.create_record!(fee, @date, Array(id))
    end

    private

    def lib_path
      __dir__
    end

    # load user company profile from config.
    #
    def set_company
      {}.tap do |h|
        h['name'] = @config.dig('company', 'name')
        h['address'] = @config.dig('company', 'address')
        h['address2'] = @config.dig('company', 'address2')
      end
    end

    # calc fee & tax amount by tax category
    #
    def subtotal(items)
      {}.tap do |subtotal|
        items.each do |i|
          rate = i.dig('type') || 'default'
          subtotal[rate] = { 'fee' => 0, 'tax' => 0 } if subtotal.dig(rate).nil?
          subtotal[rate]['fee'] += i['qty'] * i['price'] * @rate[rate]
        end
        subtotal.each do |rate, amount|
          amount['tax'] = (amount['fee'] * load_tax_rate(rate)).to_i
          amount['fee'] = amount['fee'].to_i
        end
      end
    end

    def issue_date(date)
      base =  date.nil? ? Date.today : Date.parse(date)
      Date.new(base.year, base.month, -1)
    end

    # load Tax Rate from config.
    #
    def load_tax_rate(name)
      return 0 if @config.dig('tax_rate', name).nil?

      BigDecimal(take_current(@config['tax_rate'], name).to_s)
    end

    def duplicated_contract?(id)
      self.class.asof(@date.year, @date.month, @date.day) do |_f, path|
        return true if path.include?(id)
      end
      false
    end
  end
end
