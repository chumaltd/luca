#
# manipulate files based on transaction date
#

require 'csv'
require 'date'
require 'luca_record'

module LucaBook
  class Journal < LucaRecord::Base
    @dirname = 'journals'
    @record_type = 'journal'

    # TODO: replace find(), search()->when()
    def self.find(id)
      md = /^([0-9]{4}[A-Za-z]{1})([0-9A-Za-z]{4})/.match(id)
      return nil if md.nil?
      get_records(md[1], md[2]).first
    end

    def self.search(year, month = nil, date = nil, code = nil)
      month_str = "#{year}#{encode_month(month)}"
      date_str = encode_date(date)
      get_records(month_str, date_str, code)
    end

    #
    # create journal from hash
    #
    def self.create!(d)
      date = Date.parse(d['date'])

      debit_amount = serialize_on_key(d['debit'], 'value')
      credit_amount = serialize_on_key(d['credit'], 'value')
      raise 'BalanceUnmatch' if debit_amount.inject(:+) != credit_amount.inject(:+)

      debit_code = serialize_on_key(d['debit'], 'label')
      credit_code = serialize_on_key(d['credit'], 'label')

      # TODO: limit code length for filename
      codes = (debit_code + credit_code).uniq
      create_record!(date, codes) do |f|
        f << debit_code
        f << debit_amount
        f << credit_code
        f << credit_amount
        f << [d.dig('note')]
        f << []
      end
    end

    #
    # collect values on specified key
    #
    def self.serialize_on_key(array_of_hash, key)
      array_of_hash.map { |h| h[key] }
    end

    # TODO: duplicate with LucaRecord::Io.load_journal. To be deleted
    def self.get_records(month_dir, filename = nil, code = nil, rows = 5)
      records = []
      LucaRecord::Base.open_records(@dirname, month_dir, filename, code) do |f, path|
        record = {}
        record[:id] = /^([^-]+)/.match(path.last)[1].gsub('/', '')
        CSV.new(f, headers: false, col_sep: "\t", encoding: 'UTF-8')
          .each.with_index(0) do |line, i|
          break if i >= rows

          case i
          when 0
            record[:debit] = line.map{|row| { code: row } }
          when 1
            line.each_with_index do |amount, i|
              record[:debit][i][:amount] = amount.to_i # TODO: bigdecimal support
            end
          when 2
            record[:credit] = line.map{|row| { code: row } }
            break if ! code.nil? && file.length <= 4 && ! (record[:debit]+record[:credit]).include?(code)
          when 3
            line.each_with_index do |amount, i|
              record[:credit][i][:amount] = amount.to_i # TODO: bigdecimal support
            end
          when 4
            record[:note] = line.join(' ')
          end
          record[:note] = line.first if i == 4
        end
        records << record
      end
      records
    end
  end
end
