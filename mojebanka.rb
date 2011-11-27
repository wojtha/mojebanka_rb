#!/usr/bin/ruby
# coding: utf-8

$LOAD_PATH << './'

require 'mojebanka_lib.rb'
require 'optparse'
require 'iconv'

options = {}
opt_parser = OptionParser.new do |opts|
  opts.banner = "Pouziti: mojebanka.rb [options] file1 file2 ...\n\nPriklad: ruby mojebanka.rb -f=csv *.txt"

  # Define the options, and what they do
  options[:format] = 'qif'
  opts.on( '-f', '--format FORMAT', ['qif', 'cvs'], 'Format souboru: qif, cvs') do |format|
    options[:format] = format
  end
  
  # This displays the help screen, all programs are
  # assumed to have this option.
  opts.on( '-h', '--help', 'Zobrazi napovedu' ) do
    puts opts
    exit
  end
end
 
# Parse the command-line. Remember there are two forms
# of the parse method. The 'parse' method simply parses
# ARGV, while the 'parse!' method parses ARGV and removes
# any options found there, as well as any parameters for
# the options. What's left is the list of files to resize.
opt_parser.parse!

# Filter only existing files
files = ARGV.uniq.find_all { |f| File.exist?(f); }

if files.size == 0
  puts "Argumenty neobsahovaly zadne platne soubory."
  puts opt_parser
  exit
end

files.each do |filename|
  puts "Konvertuji soubor #{filename}..."
  #fin = File.open(filename, 'r', :encoding => 'cp852')   
  fin = File.open(filename, 'r')   
  begin
    content = fin.read()
    #\xE8n\xED
    #content = Iconv.iconv('CP852//IGNORE', 'utf-8', content)    
    #content = Iconv.iconv('CP852', 'UTF-8//TRANSLIT1', content)        
    #content = Iconv.iconv('UTF-8', 'CP852', content)
    content = Iconv.conv('UTF-8', 'windows-1250', content)      
    transactions = mojebanka_txt_parse(content)
    if options[:format] == 'cvs'
      mojebanka_to_cvs(transactions)
    else
      mojebanka_to_qif(transactions)
    end
    fin.close()      
  rescue SystemCallError
    $stderr.print "IO failed: " + $!
    fin.close
    raise
  end
end