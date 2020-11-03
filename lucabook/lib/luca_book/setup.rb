# frozen_string_literal: true

require 'luca_book'
require 'fileutils'

module LucaBook
  class Setup
    # create project skeleton under specified directory
    def self.create_project(dir = LucaSupport::Config::Pjdir)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
      Dir.chdir(dir) do
        %w[data/journals dict].each do |subdir|
          FileUtils.mkdir_p(subdir) unless Dir.exist?(subdir)
        end
        FileUtils.cp("#{__dir__}/templates/dict-en.tsv", 'dict/base.tsv') unless File.exist?('config.yml')
      end
    end
  end
end
