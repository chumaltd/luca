#
# manipulate files based on transaction date
#

require 'csv'
require 'date'
require 'luca/io'
require 'luca_record'

class LucaBook
  include Luca::IO

  attr_reader :pjdir

  def initialize(dir_path=nil)
    dir_path ||= Dir.pwd
    @pjdir = set_data_dir(dir_path)
  end

  # need to be renamed
  def create!(d)
    date = Date.parse(d['date'])

    debit_amount = serialize_on_key(d['debit'], 'value')
    credit_amount = serialize_on_key(d['credit'], 'value')
    raise 'BalanceUnmatch' if debit_amount.inject(:+) != credit_amount.inject(:+)

    debit_code = serialize_on_key(d['debit'], 'label')
    credit_code = serialize_on_key(d['credit'], 'label')

    # TODO: limit code length for filename
    codes = (debit_code+credit_code).uniq
    create_record!(@pjdir, date, codes) do |f|
      f << debit_code
      f << debit_amount
      f << credit_code
      f << credit_amount
      f << [d.dig('note')]
      f << []
    end
  end

  # for assert purpose
  def gross(year, month = nil, code = nil, date_range = nil, rows = 4)
    if ! date_range.nil?
      raise if date_range.class != Range
      # TODO: date based range search
    end

    sum = { debit: {}, credit: {} }
    idx_memo = []
    month_str = "#{year}#{encode_month(month)}"
    LucaRecord::Base.open_records('journals', month_str) do |f, _path|
      CSV.new(f, headers: false, col_sep: "\t", encoding: "UTF-8")
        .each.with_index(0) do |row, i|
        break if i >= rows
        case i
        when 0
          idx_memo = row.map(&to_s)
          idx_memo.each { |r| sum[:debit][r] ||= 0 }
        when 1
          row.each_with_index { |r, i| sum[:debit][idx_memo[i]] += r.to_i } # TODO: bigdecimal support
        when 2
          idx_memo = row.map(&to_s)
          idx_memo.each { |r| sum[:credit][r] ||= 0 }
        when 3
          row.each_with_index { |r, i| sum[:credit][idx_memo[i]] += r.to_i } # TODO: bigdecimal support
        else
          puts row # for debug
        end
      end
    end
    sum
  end

  # netting vouchers in specified term
  def net(year, month = nil, code = nil, date_range = nil)
    g = gross(year, month, code, date_range)
    idx = (g[:debit].keys + g[:credit].keys).uniq.sort
    {}.tap do |sum|
      idx.each do |code|
        sum[code] = g.dig(:debit, code).nil? ? 0 : calc_diff(g[:debit][code], code)
        sum[code] -= g.dig(:credit, code).nil? ? 0 : calc_diff(g[:credit][code], code)
      end
    end
  end

  def serialize_on_key(array_of_hash, key)
    array_of_hash.map{ |h| h[key] }
  end

  def load_start
    file = @pjdir + 'start.tsv'
    {}.tap do |dic|
      load_tsv(file) do |row|
        dic[row[0]] = row[2].to_i if ! row[2].nil?
      end
    end
  end

  def calc_diff(num, code)
    amount = /\./.match(num.to_s) ? BigDecimal(num) : num.to_i
    amount * LucaBook.pn_debit(code.to_s)
  end

  def self.pn_debit(code)
    case code
    when /^[0-4BCEGH]/
      1
    when /^[5-9ADF]/
      -1
    else
      nil
    end
  end
end
