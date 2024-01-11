# frozen_string_literal: true

require 'singleton'

module LucaSupport
  class ConstantHolder
    include Singleton
    attr_reader :config, :configdir, :pjdir

    def initialize
      @pjdir = ENV['LUCA_TEST_DIR']
      @configdir = ENV['LUCA_TEST_DIR']
      @config = {
        'decimal_separator' => '.',
        'decimal_num' => 2,
        'thousands_separator' => ','
      }
    end

    def set_pjdir(path)
      @pjdir ||= path
      @configdir ||= path
    end

    def set_configdir(path)
      @configdir = path
    end

    def set_config(config)
      @config = config
    end
  end

  CONST = ConstantHolder.instance
end
