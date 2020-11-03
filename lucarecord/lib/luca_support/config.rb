# frozen_string_literal: true

#
# startup config
#
module LucaSupport
  module Config
    # Project top directory.
    Pjdir = ENV['LUCA_TEST_DIR'] || Dir.pwd.freeze
  end
end
