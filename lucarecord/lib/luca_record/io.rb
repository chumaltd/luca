# frozen_string_literal: true

require 'bigdecimal'
require 'csv'
require 'date'
require 'fileutils'
require 'json'
require 'yaml'
require 'pathname'
require 'luca_support/code'
require 'luca_support/const'

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
      # ----------------------------------------------------------------
      # :section: Query Methods
      # Provide sematic search interfaces.
      # <tt>basedir</tt> is set by class instance variable <tt>@dirname</tt>
      # of each concrete class.
      # ----------------------------------------------------------------

      # find ID based record. Support uuid and encoded date.
      def find(id, basedir = @dirname)
        return enum_for(:find, id, basedir).first unless block_given?

        if id.length >= 40
          open_hashed(basedir, id) do |f|
            yield load_data(f)
          end
        elsif id.length >= 7
          parts = id.split('/')
          open_records(basedir, parts[0], parts[1]) do |f, path|
            yield load_data(f, path)
          end
        else
          raise 'specified id length is too short'
        end
      end

      # Merge 2 files under plain & prefixed dirs.
      # prefixed contents will override duplicated keys.
      # This function does not provide encryption/decryption.
      #
      def find_secure(id, basedir = @dirname, prefix = 's_')
        if id.length >= 40
          plain = open_hashed(basedir, id) do |f|
            load_data(f)
          end
          secure = begin
                     open_hashed("#{prefix}#{basedir}", id) do |f|
                       load_data(f)
                     end
                   rescue
                     # No file exists, and so on.
                     {}
                   end
        elsif id.length >= 7
          parts = id.split('/')
          plain = open_records(basedir, parts[0], parts[1]) do |f|
            load_data(f)
          end
          secure = open_records("#{prefix}#{basedir}", parts[0], parts[1]) do |f|
            load_data(f)
          end
        else
          raise 'specified id length is too short'
        end
        plain.merge(secure)
      end

      # search date based record.
      #
      # * data hash
      # * data id. Array like [2020H, V001]
      #
      def asof(year, month = nil, day = nil, basedir = @dirname)
        return enum_for(:search, year, month, day, nil, basedir) unless block_given?

        search(year, month, day, nil, basedir) { |data, path| yield data, path }
      end

      # scan ranging data on multiple months
      #
      def term(start_year, start_month, end_year, end_month, code = nil, basedir = @dirname)
        return enum_for(:term, start_year, start_month, end_year, end_month, code, basedir) unless block_given?

        LucaSupport::Code.encode_term(start_year, start_month, end_year, end_month).each do |subdir|
          open_records(basedir, subdir, nil, code) do |f, path|
            yield load_data(f, path)
          end
        end
      end

      # search with date params & code.
      #
      def search(year, month = nil, day = nil, code = nil, basedir = @dirname)
        return enum_for(:search, year, month, day, code, basedir) unless block_given?

        subdir = year.to_s + LucaSupport::Code.encode_month(month)
        open_records(basedir, subdir, LucaSupport::Code.encode_date(day), code) do |f, path|
          yield load_data(f, path), path
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

      # [year, month] pair of the latest record
      #
      def latest_month(code = nil, basedir = @dirname)
        LucaSupport::Code.decode_term(Dir.entries(abs_path(basedir)).max)
      end

      # ----------------------------------------------------------------
      # :section: Write Methods
      # <tt>basedir</tt> is set by class instance variable <tt>@dirname</tt>
      # of each concrete class.
      # ----------------------------------------------------------------

      # create record both of uuid/date identified.
      #
      def create(obj, date: nil, codes: nil, basedir: @dirname)
        validate_keys(obj)
        if date
          create_record(obj, date, codes, basedir)
        else
          obj['id'] = LucaSupport::Code.issue_random_id
          open_hashed(basedir, obj['id'], 'w') do |f|
            f.write(YAML.dump(LucaSupport::Code.readable(obj.sort.to_h)))
          end
          obj['id']
        end
      end

      # update uuid keyed record based on 'id' field.
      # If not found, just create
      #
      def upsert(obj, basedir: @dirname)
        return nil if obj['id'].nil?

        validate_keys(obj)
        merged = begin
                    open_hashed(basedir, obj['id'], 'r') do |f|
                      load_data(f).merge(obj)
                    end
                  rescue
                    obj
                  end
        open_hashed(basedir, obj['id'], 'w') do |f|
          f.write(YAML.dump(LucaSupport::Code.readable(merged.sort.to_h)))
        end
        obj['id']
      end

      # If multiple ID matched, return short ID and human readable label.
      #
      def id_completion(phrase, label: 'name', basedir: @dirname)
        list = prefix_search(phrase, basedir: basedir)
        case list.length
        when 1
          list
        when 0
          raise 'No match on specified phrase'
        else
          (3..list[0].length).each do |l|
            if list.map { |id| id[0, l] }.uniq.length == list.length
              return list.map { |id| { id: id[0, l], label: find(id).dig(label) } }
            end
          end
        end
      end

      def prefix_search(phrase, basedir: @dirname)
        glob_str = phrase.length <= 3 ? "#{phrase}*/*" : "#{id2path(phrase)}*"
        Dir.chdir(abs_path(basedir)) do
          Dir.glob(glob_str).to_a.map! { |path| path.gsub!('/', '') }
        end
      end

      def prepare_dir!(basedir, date_obj)
        dir_name = (Pathname(basedir) + LucaSupport::Code.encode_dirname(date_obj)).to_s
        FileUtils.mkdir_p(dir_name) unless Dir.exist?(dir_name)
        dir_name
      end

      def add_status!(id, status, basedir = @dirname)
        path = abs_path(basedir) / id2path(id)
        origin = YAML.safe_load(File.read(path), permitted_classes: [Date])
        newline = { status => DateTime.now.to_s }
        origin['status'] = [] if origin['status'].nil?
        origin['status'] << newline
        File.write(path, YAML.dump(origin.sort.to_h))
      end

      # update file with obj['id']
      def save(obj, basedir = @dirname)
        if obj['id'].nil?
          create(obj, basedir)
        else
          validate_keys(obj)
          if obj['id'].length < 40
            parts = obj['id'].split('/')
            raise 'invalid ID' if parts.length != 2

            open_records(basedir, parts[0], parts[1], nil, 'w') do |f, path|
              f.write(YAML.dump(LucaSupport::Code.readable(obj.sort.to_h)))
            end
          else
            open_hashed(basedir, obj['id'], 'w') do |f|
              f.write(YAML.dump(LucaSupport::Code.readable(obj.sort.to_h)))
            end
          end
        end
        obj['id']
      end

      # delete file by id
      def delete(id, basedir = @dirname)
        FileUtils.rm(Pathname(abs_path(basedir)) / id2path(id))
        id
      end

      # change filename with new code set
      #
      def change_codes(id, new_codes, basedir = @dirname)
        raise 'invalid id' if id.split('/').length != 2

        newfile = new_codes.empty? ? id : id + '-' + new_codes.join('-')
        Dir.chdir(abs_path(basedir)) do
          origin = Dir.glob("#{id}*")
          raise 'duplicated files' if origin.length != 1

          File.rename(origin.first, newfile)
        end
        newfile
      end

      # ----------------------------------------------------------------
      # :section: Path Utilities
      # ----------------------------------------------------------------

      # Convert ID to file directory/filename path.
      # 1st element of Array is used as directory, the others as filename.
      # String without '/' is converted as git-like structure.
      # Normal argument is as follows:
      #
      #   ['2020H', 'V001', 'a7b806d04a044c6dbc4ce72932867719']
      #     => '2020H/V001-a7b806d04a044c6dbc4ce72932867719'
      #   'a7b806d04a044c6dbc4ce72932867719'
      #     => 'a7b/806d04a044c6dbc4ce72932867719'
      #   '2020H/V001'
      #     => '2020H/V001'
      def id2path(id)
        if id.is_a?(Array)
          case id.length
          when 0..2
            id.join('/')
          else
            [id[0], id[1..-1].join('-')].join('/')
          end
        elsif id.include?('/')
          id
        else
          encode_hashed_path(id).join('/')
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

      def load_project(path, ext_conf: nil)
        CONST.set_pjdir(path)
        config = {
          'decimal_separator' => '.',
          'thousands_separator' => ','
        }
        begin
          config.merge!(YAML.safe_load(
          File.read(Pathname(CONST.configdir) / 'config.yml'),
            permitted_classes: [Date]
          ))
        rescue Errno::ENOENT
          STDERR.puts "INFO: config.yml not found. Continue with default settings."
        end
        if ext_conf
          begin
            config.merge!(YAML.safe_load(
              File.read(Pathname(CONST.configdir) / ext_conf),
              permitted_classes: [Date]
            ))
          rescue Errno::ENOENT
            STDERR.puts "WARN: #{ext_conf} not found. Extended options are not effective."
          end
        end
        config['decimal_num'] ||= config['country'] == 'jp' ? 0 : 2
        CONST.set_config(config)
      end

      # test if having required dirs/files under exec path
      def valid_project?(path = CONST.pjdir)
        project_dir = Pathname(path)
        FileTest.directory?( (project_dir / 'data').to_s)
      end

      def new_record_id(basedir, date_obj)
        LucaSupport::Code.encode_txid(new_record_no(basedir, date_obj))
      end

      # Calculate md5sum under specific month directory.
      #
      def dir_digest(year, month, basedir = @dirname)
        subdir = year.to_s + LucaSupport::Code.encode_month(month)
        digest = String.new
        open_records(basedir, subdir).each do |f, path|
          digest = update_digest(digest, f.read, path[1])
        end
        digest
      end

      private

      # define new transaction ID & write data at once
      # ID format is like '2020H/A001', which means record no.1 of 2020/10/10.
      # Any data format can be written with block.
      #
      def create_record(obj, date_obj, codes = nil, basedir = @dirname)
        FileUtils.mkdir_p(abs_path(basedir)) unless Dir.exist?(abs_path(basedir))
        subdir = "#{date_obj.year}#{LucaSupport::Code.encode_month(date_obj)}"
        filename = LucaSupport::Code.encode_date(date_obj) + new_record_id(basedir, date_obj)
        obj['id'] = "#{subdir}/#{filename}" if obj.is_a? Hash
        filename += '-' + codes.join('-') if codes
        Dir.chdir(abs_path(basedir)) do
          FileUtils.mkdir_p(subdir) unless Dir.exist?(subdir)
            File.open(Pathname(subdir) / filename, 'w') do |f|
              if block_given?
                yield(f)
              else
                f.write(YAML.dump(LucaSupport::Code.readable(obj.sort.to_h)))
              end
            end
        end
        "#{subdir}/#{filename}"
      end

      # open records with 'basedir/month/date-code' path structure.
      # Glob pattern can be specified like folloing examples.
      #
      #   '2020': All month of 2020
      #   '2020[FG]': June & July of 2020
      #
      # Block will receive code fragments as 2nd parameter. Array format is:
      # 1. encoded month
      # 2. encoded day + record number of the day
      # 3. codes. More than 3 are all code set except first 2 parameters.
      def open_records(basedir, subdir, filename = nil, code = nil, mode = 'r')
        return enum_for(:open_records, basedir, subdir, filename, code, mode) unless block_given?

        file_pattern = filename.nil? ? '*' : "#{filename}*"
        Dir.chdir(abs_path(basedir)) do
          FileUtils.mkdir_p(subdir) if mode == 'w' && !Dir.exist?(subdir)
          records = Dir.glob("#{subdir}*/#{file_pattern}", sort: false)
          records = case records.find_index { |path| FileTest.file?(path) }
                    when nil
                      # TODO: file_pattern is not valid
                      Dir.glob("#{subdir}*/*/#{file_pattern}", sort: false)
                    else
                      records.sort
                    end
          records.each do |subpath|
            next if FileTest.directory?(subpath)
            next if skip_on_unmatch_code(subpath, code)

            id_set = subpath.split('/').map { |str| str.split('-') }.flatten
            File.open(subpath, mode) { |f| yield(f, id_set) }
          end
        end
      end

      # Write record with id_set supplied by open_records().
      #
      def update_record(basedir, id_set, content)
        raise "path fragments are too short" if id_set.length < 2

        ::IO.write(
          abs_path(basedir) / id_set[0] / id_set[1..-1].join('-'),
          content
        )
      end

      # Calculate md5sum with original digest, file content and filename(optional).
      #
      def update_digest(digest, str, filename = nil)
        str = filename.nil? ? str : filename + str
        content = Digest::MD5.new.update(str).hexdigest
        Digest::MD5.new.update(digest + content).hexdigest
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

      # parse data dir and respond existing months
      #
      def scan_terms(query = nil, base_dir = @dirname)
        pattern = query.nil? ? "*" : "#{query}*"
        Dir.chdir(abs_path(base_dir)) do
          Dir.glob(pattern).select { |dir|
            FileTest.directory?(dir) && /^[0-9]/.match(dir)
          }.sort.map { |str| decode_term(str) }
        end
      end

      # Decode basic format.
      # If specific decode is needed, override this method in each class.
      #
      def load_data(io, path = nil)
        raw_obj = if @record_type
                    case @record_type
                    when 'json'
                      JSON.parse(io.read)
                    end
                  else
                    YAML.safe_load(io.read, permitted_classes: [Date])
                  end
        LucaSupport::Code.decimalize(raw_obj)
          .tap { |obj| validate_keys(obj) }
      end

      def validate_keys(obj)
        return nil unless @required

        keys = obj.keys
        [].tap do |errors|
          @required.each { |r| errors << r unless keys.include?(r) }
          raise "Missing keys: #{errors.join(' ')}" unless errors.empty?
        end
      end

      # TODO: replace with data_dir method
      def abs_path(base_dir)
        Pathname(CONST.pjdir) / 'data' / base_dir
      end

      # True when file doesn't have record on code.
      # False when file may have one.
      # If filename doesn't record codes, always return false,
      # so later check is required. This is partial optimization.
      #
      def skip_on_unmatch_code(subpath, code = nil)
        # p filename.split('-')[1..-1]
        filename = subpath.split('/').last
        return false if code.nil? || filename.length <= 4

        filename.split('-')[1..-1].select { |fragment| /^#{code}/.match(fragment) }.empty?
      end

      # AUTO INCREMENT
      def new_record_no(basedir, date_obj)
        raise 'No target dir exists.' unless Dir.exist?(abs_path(basedir))

        dir_name = (Pathname(abs_path(basedir)) / LucaSupport::Code.encode_dirname(date_obj)).to_s
        return 1 unless Dir.exist?(dir_name)

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

    def load_config(path = nil)
      path = path.to_s
      if File.exist?(path)
        YAML.safe_load(File.read(path), permitted_classes: [Date])
      else
        {}
      end
    end
  end
end
