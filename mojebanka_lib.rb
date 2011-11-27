#!/usr/bin/ruby
# coding: utf-8

require "date"

def mojebanka_txt_parse(content)
  transactions = []
  cells = content.split('________________________________________________________________________________')

  re_skip = Regexp.new(/.*(ČÍSLO ÚČTU : |Obrat na vrub|Číslo protiúčtu                VS|Transakční historie|Za období      od).*/u)
  re_parse = Regexp.new(/(?<account>\d*\/\d{4})[ ]*(?<var_sym>\d*)[ ]*(?<price>-?\+?\d+,\d{2}[ ]CZK)[ ]*(?<date1>\d{2}\.\d{2}.\d{4})\r?\n
                        (?<type>|Úhrada|Inkaso)[ ]*(?<const_sym>\d+)[ ]*(?<date2>\d{2}\.\d{2}.\d{4})\r?\n
                        (?<trans_id>\d[0-9A-Z -]{14,31})[ ]*(?<date3>\d+)[ ]*(\d{2}\.\d{2}.\d{4})\r?\n
                        Popis[ ]příkazce[ ]*(?<desc1>.+)\r?\n
                        Popis[ ]pro[ ]příjemce[ ]*(?<desc2>.+)\r?\n
                        Systémový[ ]popis[ ]*(?<desc3>.+)/x)

  cells.each do |cell|
    next if re_skip.match(cell)

    match = re_parse.match(cell)

    if match
      # Copy captures from immutable MatchData to Hash and strip whitespace.
      transaction = {}
      match.names.each do |key|
        transaction[key.to_sym] = match[key].strip
      end

      # Desc 4 needs to be parsed separately
      start = cell.index("Zpráva pro příjemce")
      if start.nil? then
        transaction[:desc4] = ""
      else
        desc4 = cell.slice(start + 19, cell.length)
        desc4.sub!(/\n|\r|\t/, ' ')
        desc4.strip!
        transaction[:desc4] = desc4
      end

      # Convert dates
      [:date1, :date2, :date3].each do |key|
        if transaction[key] and transaction[key].length == 10
          transaction[key] = Date.strptime(transaction[key], '%d.%m.%Y')
        else
          transaction[key] = ""
        end
      end

      transactions << transaction
    end
  end

  return transactions
end


def mojebanka_to_cvs(transactions)
  filename = date_filename('cvs')
  fout = File.open(filename, 'w')
  begin
    columns = [:date1, :type, :account, :price, :var_sym, :desc1, :desc2, :desc3, :desc4]
    fout.write(columns.join("\t") + "\n")
    transactions.each do |tr|
      data = []
      tr[:date1] = tr[:date1].nil? ? "" : tr[:date1].strftime('%d.%m.%Y')
      columns.each { |col| data << tr[col] }
      fout.write(data.join("\t") + "\n")
    end
  rescue SystemCallError
    $stderr.print "IO failed: " + $!
    fout.close
    File.delete(fout)
    raise
  end
end

def mojebanka_to_qif(transactions)
  filename = date_filename('qif')
  fout = File.open(filename, 'w')
  begin
    fout.write("!Type:Bank\n")
    
    transactions.each do |tr|
      amount = tr[:price].sub(/\+?(-?)(\d+),(\d{2}) CZK/, '\1\2.\3').to_f

      payee = tr[:account] == '\0100' ? 'KB' : tr[:account]
      if tr[:var_sym]
        payee = payee + ' ' + tr[:var_sym]
      end

      tdate = tr[:date1].nil? ? "" : tr[:date1].strftime('%d/%m/%Y')

      data = 'D' + tdate + "\n" +
             'T' + number_format(amount) + "\n" +
             'P' + payee + "\n" +
             'M' + tr[:desc1] + ' ' + tr[:desc2] + ' ' + tr[:desc3] + ' ' + tr[:desc4] + "\n" +
             "^\n"
      fout.write(data)
    end

  rescue SystemCallError
    $stderr.print "IO failed: " + $!
    fout.close
    File.delete(fout)
    raise
  end
end


def date_filename(ext)
  "mojebanka_export_" + Time.now.strftime("%Y-%d-%m-%H-%M-%S") + "." + ext
end


def number_format(num)
  first, second = sprintf("%01.2f", num).split(".")
  if first.start_with?("-") then
    minus = "-";
    first.sub!("-", "");
  else
    minus = ""
  end
  first.reverse!
  first.gsub!(/([0-9]{3})/, '\1,')
  first.chomp!(',')
  minus + first.reverse + '.' + second
end

#DEBUG==========================================================================

=begin
content = "107399/5400                    232748902 -12,00 CZK                   10.10.2010
Inkaso                         308                                    21.10.2010
120-20101010 1010 O01ICFD      0                                      21.10.2010
Popis příkazce                 SVOBODA JAN
Popis pro příjemce             VODAFONE CZECH REPUBLIC
Systémový popis                Úhrada do jiné banky
Zpráva pro příjemce            040500975602000"

transactions = mojebanka_txt_parse(content)
mojebanka_to_qif(transactions)
=end
