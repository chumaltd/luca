#
# manipulate files based on transaction date
#

require "csv"
require 'date'
require_relative "io"

class LucaBook
  include Luca::IO, Luca::Code

  DEFAULT_PJDIR = File.expand_path("../../", __dir__)
  attr_reader :pjdir

  def initialize
    @pjdir = set_directory
  end

  def set_directory
    # todo: project directory configs
    DEFAULT_PJDIR + "/data/"
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

  def get_records(month_dir, filename=nil, code=nil, rows=4)
    records = []
    open_records(@pjdir, month_dir, filename, code) do |f, dir, file|
      record = {}
      record[:id] = dir + /^([^-]+)/.match(file)[1]
      CSV.new(f, headers: false, col_sep: "\t", encoding: "UTF-8")
        .each.with_index(0) do |line, i|
        break if i >= rows
        case i
        when 0
          record[:debit] = line.map{|row| { code: row } }
        when 1
          line.each_with_index do |amount, i|
            record[:debit][i][:amount] = amount
          end
        when 2
          record[:credit] = line.map{|row| { code: row } }
          break if ! code.nil? && file.length <= 4 && ! (record[:debit]+record[:credit]).include?(code)
        when 3
          line.each_with_index do |amount, i|
            record[:credit][i][:amount] = amount
          end
        end
        record[:note] = line.first if i == 4
      end
      records << record
    end
    records
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
