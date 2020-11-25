# frozen_string_literal: true

require 'luca_book'
require 'fileutils'

module LucaBook
  class Setup
    # create project skeleton under specified directory
    def self.create_project(country = nil, dir = LucaSupport::Config::Pjdir)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
      Dir.chdir(dir) do
        %w[data/journals data/balance dict].each do |subdir|
          FileUtils.mkdir_p(subdir) unless Dir.exist?(subdir)
        end
        dict = if File.exist?("#{__dir__}/templates/dict-#{country}.tsv")
                 "dict-#{country}.tsv"
               else
                 'dict-en.tsv'
               end
        FileUtils.cp("#{__dir__}/templates/#{dict}", 'dict/base.tsv') unless File.exist?('dict/base.tsv')
        FileUtils.cp("#{__dir__}/templates/config.yml", 'config.yml') unless File.exist?('config.yml')
        prepare_starttsv(dict) unless File.exist? 'data/balance/start.tsv'
      end
    end

    # Generate initial balance template.
    # Codes are same as base dictionary.
    # The previous month of start date is better for _date.
    #
    def self.prepare_starttsv(dict)
      CSV.open('data/balance/start.tsv', 'w', col_sep: "\t", encoding: 'UTF-8') do |csv|
        csv << ['code', 'label', 'balance']
        csv << ['_date', '2020-1-1']
        CSV.open("#{__dir__}/templates/#{dict}", 'r', col_sep: "\t", encoding: 'UTF-8').each do |row|
          csv << row if /^[1-9]/.match(row[0])
        end
      end
    end
  end
end
