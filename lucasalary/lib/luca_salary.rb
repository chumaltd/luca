# frozen_string_literal: true

require 'luca_record'
require 'luca_salary/version'

module LucaSalary
  autoload :Base, 'luca_salary/base'
  autoload :Payment, 'luca_salary/payment'
  autoload :Profile, 'luca_salary/profile'
end
