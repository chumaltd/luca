# frozen_string_literal: true

require 'csv'
require 'luca_record'
require 'luca_book/version'

module LucaBook
  autoload :Accumulator, 'luca_book/accumulator'
  autoload :Code, 'luca_book/code'
  autoload :Dict, 'luca_book/dict'
  autoload :Import, 'luca_book/import'
  autoload :Journal, 'luca_book/journal'
  autoload :List, 'luca_book/list'
  autoload :ListByHeader, 'luca_book/list_by_header'
  autoload :Setup, 'luca_book/setup'
  autoload :State, 'luca_book/state'
  autoload :Test, 'luca_book/test'
  autoload :Util, 'luca_book/util'
end
