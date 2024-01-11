# frozen_string_literal: true
require 'luca_record'

class LucaCmd
  def self.check_dir(target, ext_conf: nil)
    unless Dir.exist?('data')
      Dir.glob('*').reject { |f| File.symlink?(f) }
        .find { |f| File.directory?("#{f}/data/#{target}") }.tap do |d|
          abort "No valid data directory, exit..." if d.nil?

          Dir.chdir(d)
        end
    end
    LucaRecord::Base.load_project(Dir.pwd, ext_conf: ext_conf)
    LucaRecord::Base.valid_project?
    yield
  end
end
