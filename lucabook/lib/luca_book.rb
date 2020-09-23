#
# manipulate files based on transaction date
#

require 'csv'
require 'date'
require 'luca/io'
require 'luca_record'

class LucaBook
  include Luca::IO

  attr_reader :pjdir, :dict

  def initialize(dir_path=nil)
    dir_path ||= Dir.pwd
    @pjdir = set_data_dir(dir_path)
    @dict = load_dict
  end

  # need to be renamed
  def create!(d)
    date = Date.parse(d["date"])

    debit_amount = serialize_on_key(d["debit"], "value")
    credit_amount = serialize_on_key(d["credit"], "value")
    raise "BalanceUnmatch" if debit_amount.inject(:+) != credit_amount.inject(:+)

    debit_code = serialize_on_key(d["debit"], "label")
    credit_code = serialize_on_key(d["credit"], "label")

    # todo: limit code length for filename
    codes = (debit_code+credit_code).uniq
    create_record!(@pjdir, date, codes) do |f|
      f << debit_code
      f << debit_amount
      f << credit_code
      f << credit_amount
      f << [d.dig("note")]
      f << []
    end
  end


  def find(id)
    md = /^([0-9]{4}[A-Za-z]{1})([0-9A-Za-z]{4})/.match(id)
    return nil if md.nil?
    get_records(md[1], md[2]).first
  end

  def search(year, month=nil, date=nil, code=nil)
    month_str = "#{year.to_s}#{encode_month(month)}"
    date_str = encode_date(date)
    get_records(month_str, date_str, code)
  end

  def get_records(month_dir, filename=nil, code=nil, rows=5)
    records = []
    LucaRecord::Base.open_records('journals', month_dir, filename, code) do |f, path|
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
            record[:credit][i][:amount] = amount.to_i # todo: bigdecimal support
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

  # for assert purpose
  def gross(year, month=nil, code=nil, date_range=nil, rows=4)
    if ! date_range.nil?
      raise if date_range.class != Range
      # TODO: date based range search
    end

    sum = { debit: {}, credit: {} }
    idx_memo = []
    month_str = "#{year.to_s}#{encode_month(month)}"
    LucaRecord::Base.open_records('journals', month_str) do |f, _path|
      CSV.new(f, headers: false, col_sep: "\t", encoding: "UTF-8")
        .each.with_index(0) do |row, i|
        break if i >= rows
        case i
        when 0
          idx_memo = row.map{|r| r.to_s }
          idx_memo.each {|r| sum[:debit][r] ||= 0 }
        when 1
          row.each_with_index {|r,i| sum[:debit][idx_memo[i]] += r.to_i } # todo: bigdecimal support
        when 2
          idx_memo = row.map{|r| r.to_s }
          idx_memo.each {|r| sum[:credit][r] ||= 0 }
        when 3
          row.each_with_index {|r,i| sum[:credit][idx_memo[i]] += r.to_i } # todo: bigdecimal support
        else
          puts row # for debug
        end
      end
    end
    sum
  end

  # netting vouchers in specified term
  def net(year, month=nil, code=nil, date_range=nil)
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
    array_of_hash.map{|h| h[key]}
  end

  def load_start
    file = @pjdir + "start.tsv"
    {}.tap do |dic|
      load_tsv(file) do |row|
        dic[row[0]] = row[2].to_i if ! row[2].nil?
      end
    end
  end

  def load_dict
    file = @pjdir + "dict.tsv"
    {}.tap do |dic|
      load_tsv(file) do |row|
        entry = { label: row[1] }
        entry[:consumption_tax] = row[2].to_i if ! row[2].nil?
        entry[:income_tax] = row[3].to_i if ! row[3].nil?
        dic[row[0]] = entry
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
