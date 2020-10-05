require 'date'
require 'yaml'
require 'luca_record'

class LucaSalary::Profile < LucaRecord::Base
  @dirname = 'profiles'

  def self.gen_profile!(name)
    create({ 'name' => name })
  end
end
