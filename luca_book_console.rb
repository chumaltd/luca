require_relative "luca_book_report"

class LucaBookConsole

  def initialize(dir_path=nil)
    @report = LucaBookReport.new(dir_path)
  end

  def by_code(code, year=nil, month=nil)
    array = @report.by_code(code, year, month)

    puts "#{cnsl_fmt("ID")} #{cnsl_fmt("debit")} #{cnsl_fmt("credit")} #{cnsl_fmt("")*2} #{cnsl_fmt("balance")}"
    array.each do |h|
      puts "#{cnsl_fmt(h.dig(:id))} #{"-"*85}"
      lines = [h.dig(:debit)&.length, h.dig(:credit)&.length]&.max || 0
      lines.times do |i|
        puts "#{cnsl_fmt("")} #{cnsl_fmt(h.dig(:debit, i, :amount))}   #{cnsl_code(h.dig(:debit, i))}" if h.dig(:debit, i, :amount)
        puts "#{cnsl_fmt("")*2} #{cnsl_fmt(h.dig(:credit, i, :amount))}   #{cnsl_code(h.dig(:credit, i))}" if h.dig(:credit, i, :amount)
      end
      puts "#{cnsl_fmt(""*15)*5}   #{cnsl_fmt(h.dig(:balance))}"
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
        puts "#{h[:label]}"
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
        puts "#{h[:label]}"
        h[:value].each_slice(6).with_index(0) do |v, i|
          puts "#{cnsl_fmt(total[i], 14)} #{v.map{|v| cnsl_fmt(v, 14)}.join}"
        end
      end
    end
    puts "----  ----"
  end

  def convert_collection(obj)
    {}.tap {|res|
      obj.each.with_index(0) do |month, i|
        month.each do |k,v|
          if res.has_key?(k)
            (i - res[k].length).times{|j| res[k] << 0 } if res[k].length < i
            res[k] << v
          else
            res[k] = Array.new(i, 0)
            res[k] << v
          end
        end
      end
    }.sort.map do |k,v|
      {code: k, label: @report.dict.dig(k, :label), value: v}
    end
  end

  def cnsl_code(obj)
    code = @report.dict.dig(obj&.dig(:code))&.dig(:label) || ""
  end

  def cnsl_fmt(str, width=15, length=nil)
    length ||= width
    sprintf("%#{width}.#{length}s", str)
  end

end
