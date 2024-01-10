# frozen_string_literal: true

require 'luca_support/const'
require 'luca_record/version'

module LucaRecord
  CONST = LucaSupport::CONST

  autoload :Base, 'luca_record/base'
  autoload :Dict, 'luca_record/dict'
end
