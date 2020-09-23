require 'csv'
require 'date'
require 'erb'
require 'fileutils'
require 'open3'
require 'pathname'
require 'luca/code'
require 'luca_support/config'

# Low level API
# manipulate files based on transaction date
#
module LucaRecord
  module IO
    include Luca::Code

    def self.included(klass)
      klass.extend ClassMethods
    end

    module ClassMethods
      #
      # open records with 'basedir/month/date-code' path structure.
      # Glob pattern can be specified like folloing examples.
      #
      # * '2020': All month of 2020
      # * '2020[FG]': June & July of 2020
      #
      def open_records(basedir, subdir, filename = nil, code = nil, mode = 'r')
        return enum_for(:open_records, basedir, subdir, filename, code, mode) unless block_given?

        file_pattern = filename.nil? ? "*" : "#{filename}*"
        Dir.chdir(abs_path(basedir)) do
          Dir.glob("#{subdir}*/#{file_pattern}").sort.each do |subpath|
            next if skip_on_unmatch_code(subpath, code)

            File.open(subpath, mode) { |f| yield(f, subpath.split('/')) }
          end
        end
      end

      ###
      ### git object like structure
      ###
      def open_hashed(basedir, id, mode = 'r')
        return enum_for(:open_hashed, basedir, id, mode) unless block_given?

        subdir, filename = encode_hashed_path(id)
        dirpath = Pathname(abs_path(basedir)) + subdir
        FileUtils.mkdir_p(dirpath.to_s) if mode != 'r'
        File.open((dirpath + filename).to_s, mode) { |f| yield f }
      end

      # TODO: replace with data_dir method
      def abs_path(base_dir)
        Pathname(LucaSupport::Config::Pjdir) / 'data' / base_dir
      end

      # true when file doesn't have record on code
      # false when file may have one
      def skip_on_unmatch_code(subpath, code=nil)
        # p filename.split('-')[1..-1]
        filename = subpath.split('/').last
        return false if code.nil? or filename.length <= 4

        !filename.split('-')[1..-1].include?(code)
      end

      def encode_hashed_path(id, split_factor = 3)
        len = id.length
        if len <= split_factor
          ['', id]
        else
          [id[0, split_factor], id[split_factor, len - split_factor]]
        end
      end
    end

    def set_data_dir(dir_path = LucaSupport::Config::Pjdir)
      if dir_path.nil?
        raise 'No project path is specified'
      elsif !valid_project?(dir_path)
        raise 'Specified path is not for valid project'
      else
        project_dir = Pathname(dir_path)
      end

      (project_dir + 'data/').to_s
    end

    def valid_project?(path)
      project_dir = Pathname(path)
      FileTest.file?((project_dir + 'config.yml').to_s) and FileTest.directory?( (project_dir + 'data').to_s)
    end

    #
    # for date based records
    #
    def scan_terms(base_dir, query = nil)
      pattern = query.nil? ? "*" : "#{query}*"
      Dir.chdir(base_dir) do
        Dir.glob(pattern).select { |dir|
          FileTest.directory?(dir) && /^[0-9]/.match(dir)
        }.sort.map { |str| decode_term(str) }
      end
    end

    # define new transaction ID & write data at once
    #
    def create_record!(basedir, date_obj, codes = nil)
      gen_record_file!(basedir, date_obj, codes) do |f|
        CSV.new(f, col_sep: "\t") { |c| yield c }
      end
    end

    def gen_record_file!(basedir, date_obj, codes = nil)
      d = prepare_dir!(basedir, date_obj)
      filename = encode_date(date_obj) + new_record_id(basedir, date_obj)
      if codes
        filename += codes.inject('') { |fragment, code| "#{fragment}-#{code}" }
      end
      path = Pathname(d) + filename
      File.open(path.to_s, 'w') { |f| yield(f)  }
    end

    def new_record_id(basedir, date_obj)
      encode_txid(new_record_no(basedir, date_obj))
    end

    # AUTO INCREMENT
    def new_record_no(basedir, date_obj)
      dir_name = (Pathname(basedir) + encode_dirname(date_obj)).to_s
      raise 'No target dir exists.' unless Dir.exist?(dir_name)

      Dir.chdir(dir_name) do
        last_file = Dir.glob("#{encode_date(date_obj)}*").max
        return 1 if last_file.nil?

        return decode_txid(last_file[1, 3]) + 1
      end
    end

    def search_record(basedir, date_obj, code)
      dir_name = (Pathname(basedir) + encode_dirname(date_obj)).to_s
      raise 'No target dir exists.' unless Dir.exist?(dir_name)

      Dir.chdir(dir_name) do
        files = Dir.glob("*#{code}*")
        files.empty? ? nil : files
      end
    end

    def prepare_dir!(basedir, date_obj)
      dir_name = (Pathname(basedir) + encode_dirname(date_obj)).to_s
      FileUtils.mkdir_p(dir_name) unless Dir.exist?(dir_name)
      dir_name
    end

    def encode_dirname(date_obj)
      date_obj.year.to_s + encode_month(date_obj)
    end

    def load_config(path = nil)
      path = path.to_s
      if File.exists?(path)
        YAML.load_file(path, **{})
      else
        {}
      end
    end

    def add_status!(path, status)
      origin = YAML.load_file(path.to_s, {})
      newline = { status => DateTime.now.to_s }
      origin['status'] = [] if origin['status'].nil?
      origin['status'] << newline
      File.write(path.to_s, YAML.dump(origin.sort.to_h))
    end

    def has_status?(dat, status)
      return false if dat['status'].nil?

      dat['status'].map { |h| h.key?(status) }
        .include?(true)
    end

    def search_template(file, dir = 'templates')
      # ToDo: load config
      [@pjdir, lib_path].each do |base|
        path = (Pathname(base) / dir / file)
        return path.to_path if path.file?
      end
      nil
    end

    def load_tsv(path)
      return enum_for(:load_tsv, path) unless block_given?

      data = CSV.read(path, headers: true, col_sep: "\t", encoding: 'UTF-8')
      data.each { |row| yield row }
    end


    def save_pdf(html_dat, path)
      File.write(path, html2pdf(html_dat))
    end

    def erb2pdf(path)
      html2pdf(render_erb(path))
    end

    def render_erb(path)
      @template_dir = File.dirname(path)
      erb = ERB.new(File.read(path.to_s), trim_mode: '-')
      erb.result(binding)
    end

    def html2pdf(html_dat)
      out, err, stat = Open3.capture3('wkhtmltopdf - -', stdin_data: html_dat)
      puts err
      out
    end
  end
end
