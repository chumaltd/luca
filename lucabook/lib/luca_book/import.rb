require 'date'
require 'json'
require 'luca_book'
require 'luca_support'
require 'luca_record/dict'

module LucaBookImport
  DEBIT_DEFAULT = "273"  # 仮払金
  CREDIT_DEFAULT = "622"  # 仮受金

  module_function

  # == JSON Format:
  #   {
  #     "date": "2020-05-04",
  #     "debit" : [
  #       {
  #         "label": "savings accounts",
  #         "value": 20000
  #       }
  #     ],
  #     "credit" : [
  #       {
  #         "label": "trade notes receivable",
  #         "value": 20000
  #       }
  #     ],
  #     "note": "settlement for the last month trade"
  #   }
  #
  def import_json(io)
    d = JSON.parse(io)
    validate(d)

    dict = LucaBook::Dict.reverse_dict(LucaBook::Dict::Data)
    d["debit"].each{|h| h["label"] = search_code(dict, h["label"], DEBIT_DEFAULT) }
    d["credit"].each{|h| h["label"] = search_code(dict, h["label"], CREDIT_DEFAULT) }

    LucaBook.new.create!(d)
  end

  def validate(obj)
    raise "NoDateKey" if ! obj.has_key?("date")
    raise "NoDebitKey" if ! obj.has_key?("debit")
    raise "NoDebitValue" if obj["debit"].length < 1
    raise "NoCreditKey" if ! obj.has_key?("credit")
    raise "NoCreditValue" if obj["credit"].length < 1
  end

  def search_code(dict, str, default_code=nil)
    res = max_score_code(dict, str)
    if res[1] > 0.4
      res[0]
    else
      default_code
    end
  end

  def max_score_code(dict, str)
    res = dict.map do |k,v|
      [v, LucaSupport.match_score(str, k, 3)]
    end
    res.max { |x, y| x[1] <=> y[1] }
  end
end
