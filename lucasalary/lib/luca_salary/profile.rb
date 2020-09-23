require 'date'
require 'yaml'
require 'pathname'
require 'luca'
require 'luca_record'

class Profile
  extend Luca::IO
  extend Luca::Code

  def self.gen_profile!(name)
    id = issue_random_id
    obj = { 'id' => id, 'name' => name }
    LucaRecord::Base.open_hashed('profiles', id, 'w') do |f|
      f.write(YAML.dump(obj))
    end
  end
end
