# frozen_string_literal: true

require 'date'
require 'pathname'
require 'yaml'

# startup config
#
module LucaSupport
  PJDIR = ENV['LUCA_TEST_DIR'] || Dir.pwd.freeze
  CONFIG = begin
             {
               'decimal_separator' => '.',
               'thousands_separator' => ','
             }.merge(YAML.safe_load(File.read(Pathname(PJDIR) / 'config.yml'), permitted_classes: [Date]))
           rescue Errno::ENOENT
             {
               'decimal_separator' => '.',
               'thousands_separator' => ','
             }
           end
  CONFIG['decimal_num'] ||= CONFIG['country'] == 'jp' ? 0 : 2
end
