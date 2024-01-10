# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'

task :test do
  ['lucarecord', 'lucabook', 'lucadeal', 'lucasalary'].each do |local_gem|
    FileUtils.chdir(local_gem) { sh "rake test" }
  end
end

task default: :test
