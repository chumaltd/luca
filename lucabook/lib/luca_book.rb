# frozen_string_literal: true

require 'luca_record'
require 'luca_book/version'

module LucaBook
  autoload :Import, 'luca_book/import'
  autoload :Journal, 'luca_book/journal'
  autoload :State, 'luca_book/state'
end
