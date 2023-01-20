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
      Dir.chdir(Pathname(PJDIR) / 'data') do
        system "tar -czf - #{dir} | openssl enc -e -aes256 -iter #{iter} -out #{dir}.tar.gz"
        return if ! cleanup

        FileUtils.rm_rf dir
      end
    end

    # TODO: check space in dir string
    def decrypt(dir, iter: 10000)
      Dir.chdir(Pathname(PJDIR) / 'data') do
        system "openssl enc -d -aes256 -iter #{iter} -in #{dir}.tar.gz | tar xz"
      end
    end
  end
end
