# frozen_string_literal: true

require 'minitest/autorun'
require 'luca_book'
require 'luca_record/io'

module LucaBook # :nodoc:
  # Provide data testing framework utilizing minitest.
  #
  class Test < MiniTest::Test
    include LucaRecord::IO
    include LucaBook::Accumulator
  end
end
