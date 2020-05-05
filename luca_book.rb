#
# manipulate files based on transaction date
#

require "csv"
require 'date'
require_relative "io"

class LucaBook
  include Luca::IO

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

  def get_record(date_obj)
    records = []
    open_record(@pjdir, date_obj) do |f|
      record = { debit: [], credit: [] }
      debit_idx = []
      debit_amount = []
      credit_idx = []
      credit_amount = []
      CSV.new(f).each.with_index(0) do |line, i|
        debit_idx = line if i == 0
        credit_idx = line if i == 1
        if i == 2
          line.each_with_index do |amount, i|
            r = {}
            r[debit_idx[i]] = amount.to_i
            record[:debit] << r
          end
        elsif i == 3
          line.each_with_index do |amount, i|
            r = {}
            r[credit_idx[i]] = amount.to_i
            record[:credit] << r
          end
        end
        record[:memo] = line.first if i == 4
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
