require "csv"
require "pathname"
require_relative "io"
require_relative "luca_book"

class LucaBookReport
  include Luca::IO

  def initialize
    @book = LucaBook.new
  end

  def search_tag(code)
    count = 0
    Dir.children(@book.pjdir).sort.each do |dir|
      next if ! FileTest.directory?(@book.pjdir+dir)
      open_records(datadir, dir, 3) do |row, i|
        next if i == 2
        count += 1 if row.include?(code)
      end
    end
    puts "#{code}: #{count}"
  end

  def bs_all
    config = @book.load_dict
    accumulate_all do |f|
      puts f[:target]
      puts "---- BS ----"
      f[:diff].each do |k,v|
        if /^[0-9]/.match(k)
          if /[^0]$/.match(k)
            print "  "
            print "  " if k.length > 3
          end
          puts "#{config.dig(k, :label)}:\t #{v}"
        end
      end
      puts "---- total ----"
      f[:current].each do |k,v|
        if /^[0-9]/.match(k)
          if /[^0]$/.match(k)
            print "  "
            print "  " if k.length > 3
          end
          puts "#{config.dig(k, :label)}:\t #{v}"
        end
      end
      puts "----  ----"
    end
  end

  def pl_all
    config = @book.load_dict
    accumulate_all do |f|
      puts f[:target]
      puts "---- PL ----"
      f[:diff].each do |k,v|
        if /^[A-Z]/.match(k)
          if /[^0]$/.match(k)
            print "  "
            print "  " if k.length > 3
          end
          puts "#{config[k][:label]}:\t #{v}"
        end
      end
      puts "---- total ----"
      f[:current].each do |k,v|
        if /^[A-Z]/.match(k)
          if /[^0]$/.match(k)
            print "  "
            print "  " if k.length > 3
          end
          puts "#{config[k][:label]}:\t #{v}"
        end
      end
      puts "----  ----"
    end
  end

  def accumulate_all
    current = @book.load_start
    puts current
    Dir.children(@book.pjdir).sort.each do |dir|
      next if ! FileTest.directory?(@book.pjdir+dir)
      next if ! /^[0-9]/.match(dir)
      diff = accumulate_month(dir)
      diff.each do |k,v|
        if current[k]
          current[k] += v
        else
          current[k] = v
        end
      end
      f = { target: dir, diff: diff.sort, current: current.sort }
      yield f
    end
  end


  # todo: parse all column in each row
  def accumulate_month(dir_path)
    sum = {}
    debit_idx = []
    credit_idx = []
    open_records(@book.pjdir, dir_path) do |row, i|
      if i == 1
        debit_idx = row
        row.each {|r| sum[r.to_s] = 0 if ! sum.has_key?(r.to_s) }
      elsif i == 2
        row.each_with_index {|r,i| sum[debit_idx[i].to_s] += r.to_i * LucaBook.pn_debit(debit_idx[i].to_s) }
      elsif i == 3
        credit_idx = row
        row.each {|r| sum[r.to_s] = 0 if ! sum.has_key?(r.to_s) }
      elsif i == 4
        row.each_with_index {|r,i| sum[credit_idx[i].to_s] -= r.to_i * LucaBook.pn_debit(credit_idx[i].to_s) }
      else
        puts row
      end
    end
    total_subaccount(sum)
  end

  def total_subaccount(report)
    report.dup.tap do |res|
      report.each do |k,v|
        if k.length >= 4
          if res[k[0,3]]
            res[k[0,3]] += v
          else
            res[k[0,3]] = v
          end
        end
      end
      res["100"] = report.select {|k,v| /^[123].[^0]/.match(k)}.map{|k,v| v}.inject(0) {|s, i| s + i}
      res["400"] = report.select {|k,v| /^[4].[^0]}/.match(k)}.map{|k,v| v}.inject(0) {|s, i| s + i}
      res["500"] = report.select {|k,v| /^[56].[^0]/.match(k)}.map{|k,v| v}.inject(0) {|s, i| s + i}
      res["700"] = report.select {|k,v| /^[78].[^0]/.match(k)}.map{|k,v| v}.inject(0) {|s, i| s + i}
      res["900"] = report.select {|k,v| /^[9].[^0]/.match(k)}.map{|k,v| v}.inject(0) {|s, i| s + i}
      res["A00"] = report.select {|k,v| /^[A].[^0]/.match(k)}.map{|k,v| v}.inject(0) {|s, i| s + i}
      res["B00"] = report.select {|k,v| /^[B].[^0]/.match(k)}.map{|k,v| v}.inject(0) {|s, i| s + i}
      res["BA0"] = res["A00"] - res["B00"]
      res["C00"] = report.select {|k,v| /^[C].[^0]/.match(k)}.map{|k,v| v}.inject(0) {|s, i| s + i}
      res["CA0"] = res["BA0"] - res["C00"]
      res["D00"] = report.select {|k,v| /^[D].[^0]/.match(k)}.map{|k,v| v}.inject(0) {|s, i| s + i}
      res["E00"] = report.select {|k,v| /^[E].[^0]/.match(k)}.map{|k,v| v}.inject(0) {|s, i| s + i}
      res["EA0"] = res["CA0"] + res["D00"] - res["E00"]
      res["F00"] = report.select {|k,v| /^[F].[^0]/.match(k)}.map{|k,v| v}.inject(0) {|s, i| s + i}
      res["G00"] = report.select {|k,v| /^[G].[^0]/.match(k)}.map{|k,v| v}.inject(0) {|s, i| s + i}
      res["GA0"] = res["EA0"] + res["F00"] - res["G00"]
      res["HA0"] = res["GA0"] - report.select {|k,v| /^[H].[^0]/.match(k)}.map{|k,v| v}.inject(0){|s, i| s + i}
    end
  end

end
