# frozen_string_literal: true
require 'luca_record'
require 'pathname'

class LucaCmd
  # Search app specific dir from pwd either in direct or monorepo configuration.
  # 'config/' subdir has priority for consolidating shared config between apps.
  #
  def self.check_dir(essential_dir, ext_conf: nil)
    if Dir.exist?('config')
      LucaRecord::CONST.set_configdir(Pathname(Dir.pwd) / 'config')
    end
    unless Dir.exist?('data')
      Dir.glob('*').reject { |f| File.symlink?(f) }
        .find { |f| File.directory?("#{f}/data/#{essential_dir}") }.tap do |d|
        abort "No valid data directory, exit..." if d.nil?

        Dir.chdir(d)
        if Dir.exist?('config')
          LucaRecord::CONST.set_configdir(Pathname(Dir.pwd) / 'config')
        end
      end
    end
    LucaRecord::Base.load_project(Dir.pwd, ext_conf: ext_conf)
    yield
  end
end
