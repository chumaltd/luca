# frozen_string_literal: true

require 'csv'
require 'fileutils'
require 'yaml'
require 'pathname'
require 'luca_support/code'
require 'luca_support/config'

#
# Low level API
#
module LucaRecord
  module Dict
    include LucaSupport::Code

    def self.included(klass)
      klass.extend ClassMethods
    end

    module ClassMethods
      #
      # load dictionary data
      #
      def load(file = @filename)
        case File.extname(file)
        when '.tsv', '.csv'
          load_tsv(dict_path(file))
        when '.yaml', '.yml'
          YAML.load_file(dict_path(file), **{})
        else
          raise 'cannot load this filetype'
        end
      end

      def reverse(dict)
        dict.map{ |k, v| [v[:label], k] }.to_h
      end

      private

      def dict_path(filename)
        Pathname(LucaSupport::Config::Pjdir) / 'dict' / filename
      end

      # TODO: This is not generic code
      def load_tsv(path)
        {}.tap do |dic|
          CSV.read(path, headers: true, col_sep: "\t", encoding: 'UTF-8').each do |row|
            entry = { label: row[1] }
            entry[:consumption_tax] = row[2].to_i if ! row[2].nil?
            entry[:income_tax] = row[3].to_i if ! row[3].nil?
            dic[row[0]] = entry
          end
        end
      end
    end
  end
end
