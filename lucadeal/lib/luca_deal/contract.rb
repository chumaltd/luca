require 'luca_deal/version'

require 'yaml'
require 'pathname'
require 'luca'

module LucaDeal
  class Contract
    include Luca::IO
    include Luca::Code

    def initialize(date = nil)
      @date = date ? Date.parse(date) : Date.today
      @pjdir = Pathname(Dir.pwd)
    end

    def self.active(date, pjdir = nil)
      all(pjdir) do |data|
        next if ! active_period?(data, date)

        yield data
      end
    end

    def self.all(pjdir = nil)
      pjdir ||= Dir.pwd
      open_contracts(pjdir) do |f, name|
        data = YAML.load(f.read)
        yield data
      end
    end

    def self.open_contracts(pjdir)
      match_files = datadir(pjdir) / 'contracts' / "*" / "*"
      Dir.glob(match_files.to_s).each do |file_name|
        File.open(file_name, 'r') { |f| yield(f, file_name) }
      end
    end

    def self.datadir(pjdir)
      Pathname(pjdir) / 'data'
    end

    def generate!(customer_id)
      contract_dir = self.class.datadir(@pjdir) / 'contracts'
      id = issue_random_id
      open_hashed(self.class.datadir(@pjdir) / 'customers', customer_id) do |c|
        customer = YAML.safe_load(c.read)
        obj = { 'id' => id, 'customer_id' => customer['id'], 'customer_name' => take_active(customer, 'name') }
        obj['items'] = [{
                          'name' => '_ITEM_NAME_FOR_INVOICE_',
                          'qty' => 1,
                          'price' => 0
                        }]
        obj['terms'] = { 'billing_cycle' => 'monthly', 'effective' => @date }
        open_hashed(contract_dir, id, 'w') do |f|
          f.write(YAML.dump(obj))
        end
        id
      end
    end

    def self.active_period?(dat, date)
      defunct = dat.dig('terms', 'defunct')
      if defunct && Date.parse(defunct.to_s) < date
        false
      else
        effective = dat.dig('terms', 'effective')
        Date.parse(effective.to_s) < date
      end
    end
  end
end
