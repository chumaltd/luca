# Low level API
# manipulate files based on transaction date
#

require "csv"
require 'date'
require 'fileutils'
require_relative "code"

module Luca
  module IO
    extend Luca::Code

    ###
    ### for date based records
    ###

    # define new transaction ID & write data at once
    #
    def create_record!(basedir, date_obj, codes=nil)
      d = prepare_dir!(basedir, date_obj)
      filename = encode_date(date_obj) + new_record_id(basedir, date_obj)
      if codes
        filename += codes.inject(""){|fragment, code| "#{fragment}-#{code}" }
      end
      CSV.open(d+'/'+filename, "w", col_sep: "\t") {|f| yield f }
    end

    def open_record(basedir, date_obj, mode='r')
      dir_name = basedir + encode_dirname(date_obj)
      return nil if ! Dir.exist?(dir_name)
      Dir.chdir(dir_name) do
        Dir.glob("#{encode_date(date_obj)}*").each do |file|
          File.open(file, mode) {|f| yield f }
        end
      end
    end

    def open_records(basedir, subpath, rows=4)
      path = (Pathname(basedir) + subpath).to_s
      Dir.chdir(path) do
        Dir.glob("*").sort.each do |file|
          CSV.foreach(file, headers: false, col_sep: "\t", encoding: "UTF-8").with_index(1) do |row, i|
            break if i > rows
            yield(row, i)
          end
        end
      end
    end

    def new_record_id(basedir, date_obj)
      encode_txid(new_record_no(basedir, date_obj))
    end

    # AUTO INCREMENT
    def new_record_no(basedir, date_obj)
      dir_name = basedir + encode_dirname(date_obj)
      return 1 if ! Dir.exist?(dir_name)
      Dir.chdir(dir_name) do
        last_file = Dir.glob("#{encode_date(date_obj)}*").sort.last
        return 1 if last_file.nil?
        return decode_txid(last_file[1,3]) + 1
      end
    end

    def prepare_dir!(basedir, date_obj)
      dir_name = basedir + encode_dirname(date_obj)
      FileUtils.mkdir_p(dir_name) if ! Dir.exist?(dir_name)
      dir_name
    end

    def encode_dirname(date_obj)
      date_obj.year.to_s + encode_month(date_obj)
    end

    def load_tsv(path)
      data = CSV.read(path, headers: true, col_sep: "\t", encoding: "UTF-8")
      data.each {|row| yield row}
    end

    ###
    ### git object like structure
    ###
    def open_hashed(basedir, id, mode="r")
      subdir, filename = encode_hashed_path(id)
      dirpath = Pathname(basedir) + subdir
      FileUtils.mkdir_p(dirpath.to_s) if mode != "r"
      File.open((dirpath + filename).to_s, mode){|f| yield f}
    end

    def encode_hashed_path(id, split_factor=3)
      len = id.length
      if len <= split_factor
        ["", id]
      else
        [id[0, split_factor], id[split_factor, len-split_factor]]
      end
    end

  end
end
