# frozen_string_literal: true

require "luca_deal/version"
require 'fileutils'

module LucaDeal
  class Setup
    # create project skeleton under specified directory
    def self.create_project(dir)
      Dir.mkdir(dir) unless Dir.exist?(dir)
      Dir.chdir(dir) do
        FileUtils.cp("#{__dir__}/templates/config.yml", 'config.yml') unless File.exist?('config.yml')
        Dir.mkdir('data') unless Dir.exist?('data')
        Dir.chdir('data') do
          %w[contracts customers invoices].each do |subdir|
            Dir.mkdir(subdir) unless Dir.exist?(subdir)
          end
        end
      end
    end
  end
end
