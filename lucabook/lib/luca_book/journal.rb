#
# manipulate files based on transaction date
#

require 'csv'
require 'date'
require 'luca_record'

module LucaBook
  class Journal < LucaRecord::Base
    @dirname = 'journals'

    #
    # create journal from hash
    #
    def self.create!(d)
      date = Date.parse(d['date'])

      debit_amount = serialize_on_key(d['debit'], 'value')
      credit_amount = serialize_on_key(d['credit'], 'value')
      raise 'BalanceUnmatch' if debit_amount.inject(:+) != credit_amount.inject(:+)

      debit_code = serialize_on_key(d['debit'], 'code')
      credit_code = serialize_on_key(d['credit'], 'code')

      # TODO: limit code length for filename
      codes = (debit_code + credit_code).uniq
      create_record!(date, codes) do |f|
        f << debit_code
        f << debit_amount
        f << credit_code
        f << credit_amount
        f << []
        f << [d.dig('note')]
      end
    end

    # define new transaction ID & write data at once
    def self.create_record!(date_obj, codes = nil)
      gen_record_file!(@dirname, date_obj, codes) do |f|
        f.write CSV.generate('', col_sep: "\t", headers: false) { |c| yield(c) }
      end
    end

    #
    # collect values on specified key
    #
    def self.serialize_on_key(array_of_hash, key)
      array_of_hash.map { |h| h[key] }
    end

    #
    # override de-serializing journal format
    #
    def self.load_data(io, path)
      {}.tap do |record|
        body = false
        record[:id] = path[0] + path[1]
        CSV.new(io, headers: false, col_sep: "\t", encoding: 'UTF-8')
          .each.with_index(0) do |line, i|
          case i
          when 0
            record[:debit] = line.map { |row| { code: row } }
          when 1
            line.each_with_index do |amount, i|
              record[:debit][i][:amount] = amount.to_i # TODO: bigdecimal support
            end
          when 2
            record[:credit] = line.map { |row| { code: row } }
          when 3
            line.each_with_index do |amount, i|
              record[:credit][i][:amount] = amount.to_i # TODO: bigdecimal support
            end
          else
            if line.empty?
              record[:note] ||= []
              body = true
              next
            end
            record[:note] << line.join(' ') if body
          end
          record[:note]&.join('\n')
        end
      end
    end
  end
end
