#
# manipulate files based on transaction date
#

require 'csv'
require 'date'
require 'luca_record'

module LucaBook
  class Journal < LucaRecord::Base
    @dirname = 'journals'

    # create journal from hash
    #
    def self.create(d)
      validate(d)
      date = Date.parse(d['date'])

      debit_amount = LucaSupport::Code.decimalize(serialize_on_key(d['debit'], 'value'))
      credit_amount = LucaSupport::Code.decimalize(serialize_on_key(d['credit'], 'value'))
      raise 'BalanceUnmatch' if debit_amount.inject(:+) != credit_amount.inject(:+)

      debit_code = serialize_on_key(d['debit'], 'code')
      credit_code = serialize_on_key(d['credit'], 'code')

      # TODO: need to sync filename & content. Limit code length for filename
      # codes = (debit_code + credit_code).uniq
      codes = nil
      create_record!(date, codes) do |f|
        f << debit_code
        f << LucaSupport::Code.readable(debit_amount)
        f << credit_code
        f << LucaSupport::Code.readable(credit_amount)
        ['x-customer', 'x-editor'].each do |x_header|
          f << [x_header, d[x_header]] if d.dig(x_header)
        end
        f << []
        f << [d.dig('note')]
      end
    end

    def self.update_codes(obj)
      debit_code = serialize_on_key(obj[:debit], :code)
      credit_code = serialize_on_key(obj[:credit], :code)
      codes = (debit_code + credit_code).uniq.sort.compact
      change_codes(obj[:id], codes)
    end

    # define new transaction ID & write data at once
    def self.create_record!(date_obj, codes = nil)
      create_record(nil, date_obj, codes) do |f|
        f.write CSV.generate('', col_sep: "\t", headers: false) { |c| yield(c) }
      end
    end

    def self.validate(obj)
      raise 'NoDateKey' unless obj.key?('date')
      raise 'NoDebitKey' unless obj.key?('debit')
      raise 'NoCreditKey' unless obj.key?('credit')
      debit_codes = serialize_on_key(obj['debit'], 'code').compact
      debit_values = serialize_on_key(obj['debit'], 'value').compact
      raise 'NoDebitCode' if debit_codes.empty?
      raise 'NoDebitValue' if debit_values.empty?
      raise 'UnmatchDebit' if debit_codes.length != debit_values.length
      credit_codes = serialize_on_key(obj['credit'], 'code').compact
      credit_values = serialize_on_key(obj['credit'], 'value').compact
      raise 'NoCreditCode' if credit_codes.empty?
      raise 'NoCreditValue' if credit_values.empty?
      raise 'UnmatchCredit' if credit_codes.length != credit_values.length
    end

    # collect values on specified key
    #
    def self.serialize_on_key(array_of_hash, key)
      array_of_hash.map { |h| h[key] }
    end

    # override de-serializing journal format
    #
    def self.load_data(io, path)
      {}.tap do |record|
        body = false
        record[:id] = "#{path[0]}/#{path[1]}"
        CSV.new(io, headers: false, col_sep: "\t", encoding: 'UTF-8')
          .each.with_index(0) do |line, i|
          case i
          when 0
            record[:debit] = line.map { |row| { code: row } }
          when 1
            line.each_with_index { |amount, j| record[:debit][j][:amount] = BigDecimal(amount.to_s) }
          when 2
            record[:credit] = line.map { |row| { code: row } }
          when 3
            line.each_with_index { |amount, j| record[:credit][j][:amount] = BigDecimal(amount.to_s) }
          else
            if body == false && line.empty?
              record[:note] ||= []
              body = true
            else
              record[:note] << line.join(' ') if body
            end
          end
        end
        record[:note] = record[:note]&.join('\n')
      end
    end
  end
end
