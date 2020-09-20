require 'date'
require 'yaml'
require 'pathname'
require 'luca/code'
require 'luca/io'

class Profile
  extend Luca::IO
  extend Luca::Code

  def self.gen_profile!(name)
    profile_dir = Pathname(Dir.pwd) + 'data' + 'profiles'
    id = issue_random_id
    obj = { 'id' => id, 'name' => name }
    open_hashed(profile_dir, id, 'w') do |f|
      f.write(YAML.dump(obj))
    end
  end
end
