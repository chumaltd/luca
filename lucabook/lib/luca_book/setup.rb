# frozen_string_literal: true

require 'luca_book'
require 'fileutils'

module LucaBook
  class Setup
    # create project skeleton under specified directory
    def self.create_project(country = nil, dir = LucaSupport::Config::Pjdir)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
      Dir.chdir(dir) do
        %w[data/journals dict].each do |subdir|
          FileUtils.mkdir_p(subdir) unless Dir.exist?(subdir)
        end
        dict = if File.exist?("#{__dir__}/templates/dict-#{country}.tsv")
                 "dict-#{country}.tsv"
               else
                 'dict-en.tsv'
               end
        FileUtils.cp("#{__dir__}/templates/#{dict}", 'dict/base.tsv') unless File.exist?('dict/base.tsv')
      end
    end
  end
end
