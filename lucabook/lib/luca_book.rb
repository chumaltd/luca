# frozen_string_literal: true

require 'csv'
require 'luca_record'
require 'luca_book/version'

module LucaBook
  autoload :Dict, 'luca_book/dict'
  autoload :Import, 'luca_book/import'
  autoload :Journal, 'luca_book/journal'
  autoload :List, 'luca_book/list'
  autoload :Setup, 'luca_book/setup'
  autoload :State, 'luca_book/state'
  autoload :Util, 'luca_book/util'
end
