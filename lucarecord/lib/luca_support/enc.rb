# frozen_string_literal: true

require 'fileutils'

module LucaSupport # :nodoc:
  # Encrypt/Decrypt directory with openssl command
  #
  module Enc
    module_function

    # TODO: check if openssl/tar exists
    # TODO: handle multiple directories
    # TODO: check space in dir string
    # TODO: check if origin exists
    def encrypt(dir, iter: 10000, cleanup: false)
      passopt = ENV['LUCA_ENC_PASSWORD'] ? "-pass pass:#{ENV['LUCA_ENC_PASSWORD']}" : ''
      Dir.chdir(Pathname(CONST.pjdir) / 'data') do
        abort "Directory #{dir} not found. exit..." unless Dir.exist?(dir)

        system "tar czf - #{dir} | openssl enc -e -aes256 -iter #{iter} -out #{dir}.tar.gz #{passopt}"
        return if ! cleanup

        FileUtils.rm_rf dir
      end
    end

    # TODO: check space in dir string
    def decrypt(dir, iter: 10000)
      passopt = ENV['LUCA_ENC_PASSWORD'] ? "-pass pass:#{ENV['LUCA_ENC_PASSWORD']}" : ''
      Dir.chdir(Pathname(CONST.pjdir) / 'data') do
        abort "Archive #{dir}.tar.gz not found. exit..." unless File.exist?("#{dir}.tar.gz")

        system "openssl enc -d -aes256 -iter #{iter} -in #{dir}.tar.gz #{passopt} | tar xz"
      end
    end
  end
end
