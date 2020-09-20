require "luca_book/report"

class LucaBookConsole

  def initialize(dir_path=nil)
    @report = LucaBookReport.new(dir_path)
  end

  def all
    array = @report.scan_terms(@report.book.pjdir).map{|y,m| y}.uniq.map{|year|
      @report.book.search(year)
    }.flatten
    show_records(array)
  end

  def by_code(code, year=nil, month=nil)
    array = @report.by_code(code, year, month)
    show_records(array)
  end

  def by_month(year, month)
    array = @report.book.search(year, month)
    show_records(array)
  end

  def show_records(records)
    print "#{cnsl_fmt("ID")} #{cnsl_fmt("debit")} #{cnsl_fmt("credit")} #{cnsl_fmt("")*2}"
    print "#{cnsl_fmt("balance")}" unless records.first.dig(:balance).nil?
    puts
    records.each do |h|
      puts "#{cnsl_fmt(h.dig(:id))} #{"-"*85}"
      lines = [h.dig(:debit)&.length, h.dig(:credit)&.length]&.max || 0
      lines.times do |i|
        puts "#{cnsl_fmt("")} #{cnsl_fmt(h.dig(:debit, i, :amount))}   #{cnsl_code(h.dig(:debit, i))}" if h.dig(:debit, i, :amount)
        puts "#{cnsl_fmt("")*2} #{cnsl_fmt(h.dig(:credit, i, :amount))}   #{cnsl_code(h.dig(:credit, i))}" if h.dig(:credit, i, :amount)
      end
      puts "#{cnsl_fmt(""*15)*5}   #{cnsl_fmt(h.dig(:balance))}" unless h.dig(:balance).nil?
      puts "#{cnsl_fmt(""*15)}   #{h.dig(:note)}"
    end
  end

  def bs
    target = []
    report = []
    output = @report.accumulate_all do |f|
      target << f[:target]
      report << f[:current]
      #diff << f[:diff]
    end
    puts "---- BS ----"
    target.each_slice(6) do |v|
      puts "#{cnsl_fmt("", 14)} #{v.map{|v| cnsl_fmt(v, 14)}.join}"
    end
    convert_collection(report).each do |h|
      if /^[0-9]/.match(h[:code])
        if /[^0]$/.match(h[:code])
          print "  "
          print "  " if h[:code].length > 3
        end
        puts cnsl_label(h[:label], h[:code])
        h[:value].each_slice(6) do |v|
          puts "#{cnsl_fmt("", 14)} #{v.map{|v| cnsl_fmt(v, 14)}.join}"
        end
      end
    end
    puts "----  ----"
  end

  def pl
    target = []
    report = []
    output = @report.accumulate_all do |f|
      target << f[:target]
      report << f[:diff]
      #current << f[:current]
    end
    puts "---- PL ----"
    target.each_slice(6) do |v|
      puts "#{cnsl_fmt("", 14)} #{v.map{|v| cnsl_fmt(v, 14)}.join}"
    end
    convert_collection(report).each do |h|
      if /^[A-Z]/.match(h[:code])
        total = [h[:value].inject(:+)] + Array.new(h[:value].length)
        if /[^0]$/.match(h[:code])
          print "  "
          print "  " if h[:code].length > 3
        end
        puts cnsl_label(h[:label], h[:code])
        h[:value].each_slice(6).with_index(0) do |v, i|
          puts "#{cnsl_fmt(total[i], 14)} #{v.map{|v| cnsl_fmt(v, 14)}.join}"
        end
      end
    end
    puts "----  ----"
  end

  def convert_collection(obj)
    {}.tap {|res|
      obj.each do |month|
        month.each do |k,v|
          if res.has_key?(k)
            res[k] << v
          else
            res[k] = [v]
          end
        end
      end
    }.sort.map do |k,v|
      {code: k, label: @report.dict.dig(k, :label), value: v}
    end
  end

  def cnsl_label(label, code)
        if /[0]$/.match(code)
          cnsl_bold(label) + " " + "-"*80
        else
          label
        end
  end

  def cnsl_bold(str)
    "\e[1m#{str}\e[0m"
  end

  def cnsl_code(obj)
    code = @report.dict.dig(obj&.dig(:code))&.dig(:label) || ""
  end

  def cnsl_fmt(str, width=15, length=nil)
    length ||= width
    sprintf("%#{width}.#{length}s", str)
  end

end
