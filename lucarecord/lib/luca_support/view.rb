# frozen_string_literal: true

require 'erb'
require 'json'
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
      out, err, stat = Open3.capture3('wkhtmltopdf --enable-local-file-access - -', stdin_data: html_dat)
      STDERR.puts err
      out
    end

    # Search existing file and return path under:
    # 1. 'templates/' in Project directory that data resides
    # 2. 'templates/' in Library directory that calls LucaSupport::View#search_template
    #
    def search_template(file, dir = 'templates')
      # TODO: load config
      [CONST.pjdir, lib_path].each do |base|
        path = (Pathname(base) / dir / file)
        return path.to_path if path.file?
      end
      nil
    end

    # render mode swithes nushell Viewer
    # https://www.nushell.sh/commands/categories/viewers.html
    #
    def nushell(records, mode=:expand, columns=[])
      return nil if records.is_a?(String)

      require 'open3'
      select = if columns.empty?
                 ''
               else
                 '| select --ignore-errors ' + columns.map { |col| col.gsub(/[^a-zA-Z0-9_-]/, '') }.join(' ')
               end
      render = case mode
               when :explore
                 'explore'
               when :collapse
                 'table -c'
               else
                 'table -e'
               end
      Open3.pipeline_w(%(nu -c 'cat - | from json #{select} | #{render}')) { |stdin| stdin.puts JSON.dump(records) }
    end
  end
end
