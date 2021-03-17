# frozen_string_literal: true

require 'minitest/autorun'
require 'luca_book'
require 'luca_record/io'
require 'luca_support/range'

module LucaBook # :nodoc:
  # Provide data testing framework utilizing minitest.
  #
  class Test < MiniTest::Test
    include LucaSupport::Range
    include LucaRecord::IO
    include LucaBook::Accumulator
    include LucaBook::Util
  end
end
