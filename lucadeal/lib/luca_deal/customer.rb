require 'luca_deal/version'

require 'date'
require 'yaml'
require 'pathname'
require 'luca'

module LucaDeal
  class Customer
    include Luca::IO
    include Luca::Code

    def initialize(pjdir = nil)
      @date = Date.today
      @pjdir = pjdir || Dir.pwd
    end

    def list_name
      self.class.all(@pjdir) do |dat|
        puts "#{take_active(dat, 'id')}    #{take_active(dat, 'name')}"
      end
    end

    def self.all(pjdir = nil)
      pjdir ||= Dir.pwd
      open_customers(pjdir) do |f, name|
        data = YAML.load(f.read)
        yield data
      end
    end

    def self.open_customers(pjdir)
      match_files = datadir(pjdir) + 'customers' + "*" + "*"
      Dir.glob(match_files.to_s).each do |file_name|
        File.open(file_name, 'r') {|f| yield(f, file_name)}
      end
    end

    def self.datadir(pjdir)
      Pathname(pjdir) + 'data'
    end

    def generate!(name)
      customer_dir = self.class.datadir(@pjdir) + 'customers'
      id = issue_random_id
      contact = {
        'mail' => '_MAIL_ADDRESS_FOR_CONTACT_'
      }
      obj = {
        'id' => id,
        'name' => name,
        'address' => '_CUSTOMER_ADDRESS_FOR_INVOICE_',
        'address2' => '_CUSTOMER_ADDRESS_FOR_INVOICE_',
        'contacts' => [contact]
      }
      open_hashed(customer_dir, id, 'w') do |f|
        f.write(YAML.dump(obj))
      end
      id
    end
  end
end
