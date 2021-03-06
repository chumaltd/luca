# frozen_string_literal: true

require 'erb'
require 'open3'
require 'pathname'

module LucaSupport
  #
  # File rendering functionality like HTML, PDF.
  #
  module View
    module_function

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

    #
    # Requires wkhtmltopdf command
    #
    def html2pdf(html_dat)
      out, err, stat = Open3.capture3('wkhtmltopdf - -', stdin_data: html_dat)
      puts err
      out
    end

    # Search existing file and return path under:
    # 1. 'templates/' in Project directory that data resides
    # 2. 'templates/' in Library directory that calls LucaSupport::View#search_template
    #
    def search_template(file, dir = 'templates')
      # TODO: load config
      [LucaSupport::PJDIR, lib_path].each do |base|
        path = (Pathname(base) / dir / file)
        return path.to_path if path.file?
      end
      nil
    end

    def nushell(yml)
      require 'open3'
      Open3.pipeline_w(%(nu -c 'cat - | from yaml')) { |stdin| stdin.puts yml }
    end
  end
end
