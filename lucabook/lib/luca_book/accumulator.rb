# frozen_string_literal: true

require 'luca_book/util'
require 'luca_support/config'

module LucaBook
  module Accumulator
    def self.included(klass) #:nodoc:
      klass.extend ClassMethods
    end

    module ClassMethods
      def accumulate_month(year, month)
        monthly_record, count = net(year, month)
        [total_subaccount(monthly_record), count]
      end

      # Accumulate Level 2, 3 account.
      #
      def total_subaccount(report)
        {}.tap do |res|
          res['A0'] = sum_matched(report, /^[A][0-9A-Z]{2,}/)
          res['B0'] = sum_matched(report, /^[B][0-9A-Z]{2,}/)
          res['BA'] = res['A0'] - res['B0']
          res['C0'] = sum_matched(report, /^[C][0-9A-Z]{2,}/)
          res['CA'] = res['BA'] - res['C0']
          res['D0'] = sum_matched(report, /^[D][0-9A-Z]{2,}/)
          res['E0'] = sum_matched(report, /^[E][0-9A-Z]{2,}/)
          res['EA'] = res['CA'] + res['D0'] - res['E0']
          res['F0'] = sum_matched(report, /^[F][0-9A-Z]{2,}/)
          res['G0'] = sum_matched(report, /^[G][0-9][0-9A-Z]{1,}/)
          res['GA'] = res['EA'] + res['F0'] - res['G0']
          res['H0'] = sum_matched(report, /^[H][0-9][0-9A-Z]{1,}/)
          res['HA'] = res['GA'] - res['H0']

          report['9142'] = (report['9142'] || BigDecimal('0')) + res['HA']
          res['9142'] = report['9142']
          res['10'] = sum_matched(report, /^[12][0-9A-Z]{2,}/)
          jp_4v = sum_matched(report, /^[4][V]{2,}/) # deferred assets for JP GAAP
          res['30'] = sum_matched(report, /^[34][0-9A-Z]{2,}/) - jp_4v
          res['4V'] = jp_4v if LucaSupport::CONFIG['country'] == 'jp'
          res['50'] = sum_matched(report, /^[56][0-9A-Z]{2,}/)
          res['70'] = sum_matched(report, /^[78][0-9A-Z]{2,}/)
          res['91'] = sum_matched(report, /^91[0-9A-Z]{1,}/)
          res['8ZZ'] = res['50'] + res['70']
          res['9ZZ'] = sum_matched(report, /^[9][0-9A-Z]{2,}/)

          res['1'] = res['10'] + res['30']
          res['5'] = res['8ZZ'] + res['9ZZ']
          res['_d'] = report['_d']

          report.each do |k, v|
            res[k] ||= sum_matched(report, /^#{k}[0-9A-Z]{1,}/) if k.length == 2
            res[k] = v if k.length == 3
          end

          report.each do |k, v|
            if k.length >= 4
              if res[k[0, 3]]
                res[k[0, 3]] += v
              else
                res[k[0, 3]] = v
              end
              res[k] = v
            end
          end
          res.sort.to_h
        end
      end

      def sum_matched(report, reg)
        report.select { |k, v| reg.match(k)}.values.sum
      end

      # for assert purpose
      #
      # header: { customer: 'some-customer' }
      #
      def gross(start_year, start_month, end_year = nil, end_month = nil, code:  nil, date_range: nil, rows: 4, recursive: false, header: nil)
        if ! date_range.nil?
          raise if date_range.class != Range
          # TODO: date based range search
        end
        scan_headers = header&.map { |k, v|
          [:customer, :editor].include?(k) ? [ "x-#{k.to_s}", v ] : nil
        }&.compact&.to_h

        end_year ||= start_year
        end_month ||= start_month
        sum = { debit: {}, credit: {}, debit_count: {}, credit_count: {} }
        idx_memo = []

        enm = if scan_headers.nil? || scan_headers.empty?
                term(start_year, start_month, end_year, end_month, code, 'journals')
              else
                Enumerator.new do |y|
                  term(start_year, start_month, end_year, end_month, code, 'journals') do |f, path|
                    4.times { f.gets } # skip to headers
                    CSV.new(f, headers: false, col_sep: "\t", encoding: 'UTF-8')
                      .each do |line|
                      break if line.empty?

                      if scan_headers.keys.include? line[0]
                        f.rewind
                        y << [f, path]
                      end
                    end
                  end
                end
              end
        enm.each do |f, _path|
          CSV.new(f, headers: false, col_sep: "\t", encoding: 'UTF-8')
            .each_with_index do |row, i|
            break if i >= rows

            case i
            when 0
              idx_memo = row.map(&:to_s)
              next if code && idx_memo.select { |idx| /^#{code}/.match(idx) }.empty?

              idx_memo.each do |r|
                sum[:debit][r] ||= BigDecimal('0')
                sum[:debit_count][r] ||= 0
              end
            when 1
              next if code && idx_memo.select { |idx| /^#{code}/.match(idx) }.empty?

              row.each_with_index do |r, j|
                sum[:debit][idx_memo[j]] += BigDecimal(r.to_s)
                sum[:debit_count][idx_memo[j]] += 1
              end
            when 2
              idx_memo = row.map(&:to_s)
              break if code && idx_memo.select { |idx| /^#{code}/.match(idx) }.empty?

              idx_memo.each do |r|
                sum[:credit][r] ||= BigDecimal('0')
                sum[:credit_count][r] ||= 0
              end
            when 3
              row.each_with_index do |r, j|
                sum[:credit][idx_memo[j]] += BigDecimal(r.to_s)
                sum[:credit_count][idx_memo[j]] += 1
              end
            else
              puts row # for debug
            end
          end
        end
        return sum if code.nil?

        codes = if recursive
                  sum[:debit].keys.concat(sum[:credit].keys).uniq.select { |k| /^#{code}/.match(k) }
                else
                  Array(code)
                end
        res = { debit: { code => 0 }, credit: { code => 0 }, debit_count: { code => 0 }, credit_count: { code => 0 } }
        codes.each do |cd|
          res[:debit][code] += sum[:debit][cd] || BigDecimal('0')
          res[:credit][code] += sum[:credit][cd] || BigDecimal('0')
          res[:debit_count][code] += sum[:debit_count][cd] || 0
          res[:credit_count][code] += sum[:credit_count][cd] || 0
        end
        res
      end

      # netting vouchers in specified term
      #
      def net(start_year, start_month, end_year = nil, end_month = nil, code: nil, date_range: nil, recursive: false, header: nil)
        g = gross(start_year, start_month, end_year, end_month, code: code, date_range: date_range, recursive: recursive, header: header)
        idx = (g[:debit].keys + g[:credit].keys).uniq.sort
        count = {}
        diff = {}.tap do |sum|
          idx.each do |code|
            sum[code] = g.dig(:debit, code).nil? ? BigDecimal('0') : LucaBook::Util.calc_diff(g[:debit][code], code)
            sum[code] -= g.dig(:credit, code).nil? ? BigDecimal('0') : LucaBook::Util.calc_diff(g[:credit][code], code)
            count[code] = (g.dig(:debit_count, code) || 0) + (g.dig(:credit_count, code) || 0)
          end
        end
        [diff, count]
      end

      # Override LucaRecord::IO.load_data
      #
      def load_data(io, path = nil)
        io
      end
    end

    def net_amount(code, start_year = nil, start_month = nil, end_year = nil, end_month = nil, recursive: true)
      start_year ||= @cursor_start&.year || @start_date.year
      start_month ||= @cursor_start&.month || @start_date.month
      end_year ||= @cursor_end&.year || @end_date.year
      end_month ||= @cursor_end&.month || @end_date.month
      self.class.net(start_year, start_month, end_year, end_month, code: code, recursive: recursive)[0][code]
    end

    def debit_amount(code, start_year = nil, start_month = nil, end_year = nil, end_month = nil, recursive: true)
      gross_amount(code, start_year, start_month, end_year, end_month, recursive: recursive)[0]
    end

    def credit_amount(code, start_year = nil, start_month = nil, end_year = nil, end_month = nil, recursive: true)
      gross_amount(code, start_year, start_month, end_year, end_month, recursive: recursive)[1]
    end

    def gross_amount(code, start_year = nil, start_month = nil, end_year = nil, end_month = nil, recursive: true)
      start_year ||= @cursor_start&.year || @start_date.year
      start_month ||= @cursor_start&.month || @start_date.month
      end_year ||= @cursor_end&.year || @end_date.year
      end_month ||= @cursor_end&.month || @end_date.month
      g = self.class.gross(start_year, start_month, end_year, end_month, code: code, recursive: recursive)
      [g[:debit][code], g[:credit][code]]
    end

    def debit_count(code, start_year = nil, start_month = nil, end_year = nil, end_month = nil, recursive: true)
      gross_count(code, start_year, start_month, end_year, end_month, recursive: recursive)[0]
    end

    def credit_count(code, start_year = nil, start_month = nil, end_year = nil, end_month = nil, recursive: true)
      gross_count(code, start_year, start_month, end_year, end_month, recursive: recursive)[1]
    end

    def gross_count(code, start_year = nil, start_month = nil, end_year = nil, end_month = nil, recursive: true)
      start_year ||= @cursor_start&.year || @start_date.year
      start_month ||= @cursor_start&.month || @start_date.month
      end_year ||= @cursor_end&.year || @end_date.year
      end_month ||= @cursor_end&.month || @end_date.month
      g = self.class.gross(start_year, start_month, end_year, end_month, code: code, recursive: recursive)
      [g[:debit_count][code], g[:credit_count][code]]
    end

    def each_month
      yield
    end
  end
end
