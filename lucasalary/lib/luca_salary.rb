# frozen_string_literal: true

require 'luca_record'
require 'luca_salary/version'

module LucaSalary
  autoload :Accumulator, 'luca_salary/accumulator'
  autoload :Base, 'luca_salary/base'
  autoload :Payment, 'luca_salary/payment'
  autoload :Profile, 'luca_salary/profile'
  autoload :State, 'luca_salary/state'
  autoload :Total, 'luca_salary/total'
end
