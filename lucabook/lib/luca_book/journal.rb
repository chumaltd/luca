# frozen_string_literal: true

require 'csv'
require 'date'
require 'luca_record'

module LucaBook #:nodoc:
  # Journal has several annotations on headers:
  #
  # x-customer::
  #     Identifying customer.
  # x-editor::
  #     Application name editing the journal.
  # x-tax::
  #     For tracking tax related transaction.
  #
  class Journal < LucaRecord::Base
    ACCEPTED_HEADERS = ['x-customer', 'x-editor', 'x-tax']
    @dirname = 'journals'

    # create journal from hash
    #
    def self.create(dat)
      d = LucaSupport::Code.keys_stringify(dat)
      validate(d)
      raise 'NoDateKey' unless d.key?('date')

      date = Date.parse(d['date'])

      # TODO: need to sync filename & content. Limit code length for filename
      # codes = (debit_code + credit_code).uniq
      codes = nil

      create_record(nil, date, codes) { |f| f.write journal2csv(d) }
    end

    # update journal with hash.
    # If record not found with id, no record will be created.
    #
    def self.save(dat)
      d = LucaSupport::Code.keys_stringify(dat)
      raise 'record has no id.' if d['id'].nil?

      validate(d)
      parts = d['id'].split('/')
      raise 'invalid ID' if parts.length != 2

      codes = nil
      open_records(@dirname, parts[0], parts[1], codes, 'w') { |f, _path| f.write journal2csv(d) }
    end

    # Convert journal object to TSV format.
    #
    def self.journal2csv(d)
      debit_amount = LucaSupport::Code.decimalize(serialize_on_key(d['debit'], 'amount'))
      credit_amount = LucaSupport::Code.decimalize(serialize_on_key(d['credit'], 'amount'))
      raise 'BalanceUnmatch' if debit_amount.inject(:+) != credit_amount.inject(:+)

      debit_code = serialize_on_key(d['debit'], 'code')
      credit_code = serialize_on_key(d['credit'], 'code')

      csv = CSV.generate(String.new, col_sep: "\t", headers: false) do |f|
        f << debit_code
        f << LucaSupport::Code.readable(debit_amount)
        f << credit_code
        f << LucaSupport::Code.readable(credit_amount)
        ACCEPTED_HEADERS.each do |x_header|
          f << [x_header, d['headers'][x_header]] if d.dig('headers', x_header)
        end
        f << []
        f << [d.dig('note')]
      end
    end

    # Set accepted header with key/value
    #
    def self.add_header(journal_hash, key, val)
      return journal_hash if val.nil?
      return journal_hash unless ACCEPTED_HEADERS.include?(key)

      journal_hash.tap do |o|
        o[:headers] = {} unless o.dig(:headers)
        o[:headers][key] = val
        save o
      end
    end

    def self.update_codes(obj)
      debit_code = serialize_on_key(obj[:debit], :code)
      credit_code = serialize_on_key(obj[:credit], :code)
      codes = (debit_code + credit_code).uniq.sort.compact
      change_codes(obj[:id], codes)
    end

    def self.validate(obj)
      raise 'NoDebitKey' unless obj.key?('debit')
      raise 'NoCreditKey' unless obj.key?('credit')
      debit_codes = serialize_on_key(obj['debit'], 'code').compact
      debit_amount = serialize_on_key(obj['debit'], 'amount').compact
      raise 'NoDebitCode' if debit_codes.empty?
      raise 'NoDebitAmount' if debit_amount.empty?
      raise 'UnmatchDebit' if debit_codes.length != debit_amount.length
      credit_codes = serialize_on_key(obj['credit'], 'code').compact
      credit_amount = serialize_on_key(obj['credit'], 'amount').compact
      raise 'NoCreditCode' if credit_codes.empty?
      raise 'NoCreditAmount' if credit_amount.empty?
      raise 'UnmatchCredit' if credit_codes.length != credit_amount.length
    end

    # collect values on specified key
    #
    def self.serialize_on_key(array_of_hash, key)
      array_of_hash.map { |h| h[key] }
    end

    # override de-serializing journal format. Sample format is:
    #
    #   {
    #     id: '2021A/V001',
    #     headers: {
    #       'x-customer' => 'Some Customer Co.'
    #     },
    #     debit: [
    #       { code: 'A12', amount: 1000 }
    #     ],
    #     credit: [
    #       { code: '311', amount: 1000 }
    #     ],
    #     note: 'note for each journal'
    #   }
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
            case body
            when false
              if line.empty?
                record[:note] ||= []
                body = true
              else
                record[:headers] ||= {}
                record[:headers][line[0]] = line[1]
              end
            when true
              record[:note] << line.join(' ') if body
            end
          end
        end
        record[:note] = record[:note]&.join('\n')
      end
    end
  end
end
