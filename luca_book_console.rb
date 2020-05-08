require_relative "luca_book_report"

class LucaBookConsole

  def initialize
    @report = LucaBookReport.new
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

  def cnsl_code(obj)
    code = @report.dict.dig(obj&.dig(:code))&.dig(:label) || ""
  end

  def cnsl_fmt(str)
    sprintf("%15.15s", str)
  end

end
