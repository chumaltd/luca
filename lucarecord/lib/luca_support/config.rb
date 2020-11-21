# frozen_string_literal: true

require 'pathname'
require 'yaml'

# startup config
#
module LucaSupport
  PJDIR = ENV['LUCA_TEST_DIR'] || Dir.pwd.freeze
  CONFIG = begin
             YAML.load_file(Pathname(PJDIR) / 'config.yml', **{})
           rescue Errno::ENOENT
             {}
           end

  module Config
    # Project top directory.
    Pjdir = ENV['LUCA_TEST_DIR'] || Dir.pwd.freeze
    if File.exist?(Pathname(Pjdir) / 'config.yml')
      # DECIMAL_NUM = YAML.load_file(Pathname(Pjdir) / 'config.yml', **{})['decimal_number']
      COUNTRY = YAML.load_file(Pathname(Pjdir) / 'config.yml', **{})['country']
      DECIMAL_NUM ||= 0 if COUNTRY == 'jp'
    end
    DECIMAL_NUM ||= 2
  end
end
