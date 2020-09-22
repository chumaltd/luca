# frozen_string_literal: true
require 'csv'
require 'date'
require 'fileutils'
require 'pathname'

def load_dict_tsv(dir)
  file = File.expand_path('./dict/code.tsv', dir)
  data = CSV.read(file, headers: true, col_sep: "\t", encoding: 'UTF-8')
  {}.tap do |dic|
    data.each do |row|
      entry = { label: row[1], acct_label: row.dig(2) }
      dic[row[0]] = entry
    end
  end
end
