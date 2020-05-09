require "csv"
require "pathname"
require_relative "io"
require_relative "luca_book"

class LucaBookReport
  include Luca::IO

  attr_reader :book

  def initialize(dir_path=nil)
    @book = LucaBook.new(dir_path)
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

  def by_code(code, year=nil, month=nil)
    raise "not supported year range yet" if ! year.nil? && month.nil?
    bl = @book.load_start.dig(code) || 0
    full_term = scan_terms(@book.pjdir)
    if ! month.nil?
      pre_term = full_term.select{|y,m| y <= year && m < month }
      bl += pre_term.map{|y,m| @book.net(y, m)}.inject(0){|sum, h| sum + h[code]}
      [{ code: code, balance: bl, note: "#{code} #{dict.dig(code, :label)}" }] + records_with_balance(year, month, code, bl)
    else
      start = { code: code, balance: bl, note: "#{code} #{dict.dig(code, :label)}" }
      full_term.map {|y, m| y }.uniq.map {|y|
        records_with_balance(y, nil, code, bl)
      }.flatten.prepend(start)
    end
  end

  def records_with_balance(year, month, code, balance)
      @book.search(year, month, nil, code).each do |h|
        balance += @book.calc_diff(amount_by_code(h[:debit], code), code) - @book.calc_diff(amount_by_code(h[:credit], code), code)
        h[:balance] = balance
      end
  end

  def accumulate_all
    current = @book.load_start
    target = []
    Dir.chdir(@book.pjdir) do
      net_records = scan_terms(@book.pjdir).map {|year, month|
        target << [year, month]
        accumulate_month(year, month)
      }
      all_keys = net_records.map{|h| h.keys}.flatten.uniq
      net_records.each.with_index(0) do |diff, i|
        all_keys.each {|key| diff[key] = 0 unless diff.has_key?(key)}
        diff.each do |k,v|
          if current[k]
            current[k] += v
          else
            current[k] = v
          end
        end
        f = { target: "#{target[i][0]}-#{target[i][1]}", diff: diff.sort, current: current.sort }
        yield f
      end
    end
  end

  def accumulate_month(year, month)
    monthly_record = @book.net(year, month)
    total_subaccount(monthly_record)
  end

  def amount_by_code(items, code)
    items
      .select{|item| item.dig(:code) == code }
      .inject(0){|sum, item| sum + item[:amount] }
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

  def dict
    @book.dict
  end

end
