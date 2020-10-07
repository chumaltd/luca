# frozen_string_literal: true

require 'csv'
require 'date'
require 'fileutils'
require 'yaml'
require 'pathname'
require 'luca_support/code'
require 'luca_support/config'

module LucaRecord # :nodoc:
  # == IO
  # Read / Write hash data with id and/or date.
  # Manage both database & historical records.
  module IO
    include LucaSupport::Code

    def self.included(klass) # :nodoc:
      klass.extend ClassMethods
    end

    module ClassMethods
      #-----------------------------------------------------------------
      # :section: Query Methods
      # Provide sematic search interfaces.
      # <tt>basedir</tt> is set by class instance variable <tt>@dirname</tt>
      # of each concrete class.
      #-----------------------------------------------------------------

      # find ID based record. Support uuid and encoded date.
      def find(id, basedir = @dirname)
        return enum_for(:find, id, basedir) unless block_given?

        if id.length >= 40
          open_hashed(basedir, id) do |f|
            yield load_data(f)
          end
        elsif id.length >= 9
          # TODO: need regexp match for more flexible coding(after AD9999)
          open_records(basedir, id[0, 5], id[5, 6]) do |f, path|
            yield load_data(f, path)
          end
        else
          raise 'specified id length is too short'
        end
      end

      # search date based record.
      #
      # * data hash
      # * data id. Array like [2020H, V001]
      #
      def asof(year, month = nil, day = nil, basedir = @dirname)
        return enum_for(:search, year, month, day, nil, basedir) unless block_given?

        search(year, month, day, nil, basedir) do |data, path|
          yield data, path
        end
      end

      # search with date params & code.
      #
      def search(year, month = nil, day = nil, code = nil, basedir = @dirname)
        return enum_for(:search, year, month, day, code, basedir) unless block_given?

        subdir = year.to_s + LucaSupport::Code.encode_month(month)
        open_records(basedir, subdir, LucaSupport::Code.encode_date(day), code) do |f, path|
          if @record_type == 'raw'
            yield f, path
          else
            yield load_data(f, path), path
          end
        end
      end

      # retrieve all data
      #
      def all(basedir = @dirname)
        return enum_for(:all, basedir) unless block_given?

        open_all(basedir) do |f| 
          yield load_data(f)
        end
      end

      #-----------------------------------------------------------------
      # :section: Write Methods
      # <tt>basedir</tt> is set by class instance variable <tt>@dirname</tt>
      # of each concrete class.
      #-----------------------------------------------------------------

      # create hash based record
      def create(obj, basedir = @dirname)
        id = LucaSupport::Code.issue_random_id
        obj['id'] = id
        open_hashed(basedir, id, 'w') do |f|
          f.write(YAML.dump(obj.sort.to_h))
        end
        id
      end

      # define new transaction ID & write data at once
      def create_record!(obj, date_obj, codes = nil, basedir = @dirname)
        gen_record_file!(basedir, date_obj, codes) do |f|
          f.write(YAML.dump(obj.sort.to_h))
        end
      end

      def prepare_dir!(basedir, date_obj)
        dir_name = (Pathname(basedir) + encode_dirname(date_obj)).to_s
        FileUtils.mkdir_p(dir_name) unless Dir.exist?(dir_name)
        dir_name
      end

      def add_status!(id, status, basedir = @dirname)
        path = abs_path(basedir) / id2path(id)
        origin = YAML.load_file(path, {})
        newline = { status => DateTime.now.to_s }
        origin['status'] = [] if origin['status'].nil?
        origin['status'] << newline
        File.write(path, YAML.dump(origin.sort.to_h))
      end

      #-----------------------------------------------------------------
      # :section: Path Utilities
      #-----------------------------------------------------------------

      # convert ID to file path. Normal argument is as follows:
      #
      #   [2020H, V001]
      #   "2020H/V001"
      #   "a7b806d04a044c6dbc4ce72932867719"
      def id2path(id)
        if id.is_a?(Array)
          id.join('/')
        elsif id.include?('/')
          id
        else
          encode_hashed_path(id)
        end
      end

      # Directory separation for performance. Same as Git way.
      def encode_hashed_path(id, split_factor = 3)
        len = id.length
        if len <= split_factor
          ['', id]
        else
          [id[0, split_factor], id[split_factor, len - split_factor]]
        end
      end

      def encode_dirname(date_obj)
        date_obj.year.to_s + LucaSupport::Code.encode_month(date_obj)
      end

      # test if having required dirs/files under exec path
      def valid_project?(path = LucaSupport::Config::Pjdir)
        project_dir = Pathname(path)
        FileTest.file?((project_dir + 'config.yml').to_s) and FileTest.directory?( (project_dir + 'data').to_s)
      end

      def new_record_id(basedir, date_obj)
        LucaSupport::Code.encode_txid(new_record_no(basedir, date_obj))
      end

      private

      # open records with 'basedir/month/date-code' path structure.
      # Glob pattern can be specified like folloing examples.
      #
      #   '2020': All month of 2020
      #   '2020[FG]': June & July of 2020
      #
      # Block will receive code fragments as 2nd parameter. Array format is as bellows:
      # 1. encoded month
      # 2. encoded day + record number of the day
      # 3. codes. More than 3 are all code set except first 2 parameters.
      def open_records(basedir, subdir, filename = nil, code = nil, mode = 'r')
        return enum_for(:open_records, basedir, subdir, filename, code, mode) unless block_given?

        file_pattern = filename.nil? ? '*' : "#{filename}*"
        Dir.chdir(abs_path(basedir)) do
          Dir.glob("#{subdir}*/#{file_pattern}").sort.each do |subpath|
            next if skip_on_unmatch_code(subpath, code)

            id_set = subpath.split('/').map { |str| str.split('-') }.flatten
            File.open(subpath, mode) { |f| yield(f, id_set) }
          end
        end
      end

      # git object like structure
      #
      def open_hashed(basedir, id, mode = 'r')
        return enum_for(:open_hashed, basedir, id, mode) unless block_given?

        subdir, filename = encode_hashed_path(id)
        dirpath = Pathname(abs_path(basedir)) + subdir
        FileUtils.mkdir_p(dirpath.to_s) if mode != 'r'
        File.open((dirpath + filename).to_s, mode) { |f| yield f }
      end

      # scan through all files
      #
      def open_all(basedir, mode = 'r')
        return enum_for(:open_all, basedir, mode) unless block_given?

        dirpath = Pathname(abs_path(basedir)) / '*' / '*'
        Dir.glob(dirpath.to_s).each do |filename|
          File.open(filename, mode) { |f| yield f }
        end
      end

      # Decode basic format.
      # If specific decode is needed, override this method in each class.
      #
      def load_data(io, path = nil)
        case @record_type
        when 'raw'
          # TODO: raw may be unneeded in favor of override
          io
        when 'json'
        # TODO: implement JSON parse
        else
          YAML.load(io.read)
        end
      end

      def gen_record_file!(basedir, date_obj, codes = nil)
        d = prepare_dir!(abs_path(basedir), date_obj)
        filename = LucaSupport::Code.encode_date(date_obj) + new_record_id(abs_path(basedir), date_obj)
        if codes
          filename += codes.inject('') { |fragment, code| "#{fragment}-#{code}" }
        end
        path = Pathname(d) + filename
        File.open(path.to_s, 'w') { |f| yield(f) }
      end

      # TODO: replace with data_dir method
      def abs_path(base_dir)
        Pathname(LucaSupport::Config::Pjdir) / 'data' / base_dir
      end

      # true when file doesn't have record on code
      # false when file may have one
      def skip_on_unmatch_code(subpath, code = nil)
        # p filename.split('-')[1..-1]
        filename = subpath.split('/').last
        return false if code.nil? || filename.length <= 4

        !filename.split('-')[1..-1].include?(code)
      end

      # AUTO INCREMENT
      def new_record_no(basedir, date_obj)
        dir_name = (Pathname(basedir) + encode_dirname(date_obj)).to_s
        raise 'No target dir exists.' unless Dir.exist?(dir_name)

        Dir.chdir(dir_name) do
          last_file = Dir.glob("#{LucaSupport::Code.encode_date(date_obj)}*").max
          return 1 if last_file.nil?

          return LucaSupport::Code.decode_txid(last_file[1, 3]) + 1
        end
      end
    end # end of ClassModules

    # Used @date for searching current settings
    # query can be nested hash for other than 'val'
    #
    #   where(contract_status: 'active')
    #   where(graded: {rank: 5})
    #
    def where(**query)
      return enum_for(:where, **query) unless block_given?

      query.each do |key, val|
        v = val.respond_to?(:values) ? val.values.first : val
        label = val.respond_to?(:keys) ? val.keys.first : 'val'
        self.class.all do |data|
          next unless data.keys.map(&:to_sym).include?(key)

          processed = parse_current(data)
          yield processed if v == processed.dig(key.to_s, label.to_s)
        end
      end
    end

    # parse data dir and respond existing months
    #
    def scan_terms(base_dir, query = nil)
      pattern = query.nil? ? "*" : "#{query}*"
      Dir.chdir(base_dir) do
        Dir.glob(pattern).select { |dir|
          FileTest.directory?(dir) && /^[0-9]/.match(dir)
        }.sort.map { |str| decode_term(str) }
      end
    end

    def load_config(path = nil)
      path = path.to_s
      if File.exist?(path)
        YAML.load_file(path, **{})
      else
        {}
      end
    end
  end
end
