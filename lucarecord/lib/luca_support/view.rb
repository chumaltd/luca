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

    def search_template(file, dir = 'templates')
      # TODO: load config
      [@pjdir, lib_path].each do |base|
        path = (Pathname(base) / dir / file)
        return path.to_path if path.file?
      end
      nil
    end
  end
end
