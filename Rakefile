# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'pathname'
require 'securerandom'

Rake::TestTask.new(:test) do |t|
  #t.libs << 'test'
  #t.libs << 'lib'
  t.test_files = FileList['lucarecord/test/**/*_test.rb', 'lucabook/test/**/*_test.rb', 'lucadeal/test/**/*_test.rb']
end

ENV['LUCA_TEST_DIR'] = (Pathname(__dir__) / 'tmp' / SecureRandom.uuid).to_s
FileUtils.mkdir_p(ENV['LUCA_TEST_DIR'])
FileUtils.chdir(ENV['LUCA_TEST_DIR']) do
  task default: :test
end
