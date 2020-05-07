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

    def scan_terms(base_dir, query=nil)
      pattern = query.nil? ? "*" : "#{query}*"
      Dir.chdir(base_dir) do
        Dir.glob(pattern).select do |dir|
          FileTest.directory?(dir) && /^[0-9]/.match(dir)
        end
      end
    end

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

    def open_records(basedir, subdir, filename=nil, code=nil, mode="r")
      file_pattern = filename.nil? ? "*" : "#{filename}*"
      Dir.chdir(basedir) do
        Dir.glob("#{subdir}*").sort.each do |d|
          Dir.chdir(d) do
            Dir.glob(file_pattern).sort.each do |file|
              next if skip_on_unmatch_code(file, code)
              File.open(file, mode) {|f| yield(f, d, file)  }
            end
          end
        end
      end
    end

    # true when file doesn't have record on code
    # false when file may have one
    def skip_on_unmatch_code(filename, code=nil)
      #p filename.split('-')[1..-1]
      return false if code.nil? or filename.length <= 4
      ! filename.split('-')[1..-1].include?(code)
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
