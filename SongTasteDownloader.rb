#! /usr/bin/env ruby 
#-*- coding: utf-8 -*-
# Author: qjp
# Date: <2014-09-11 Thu>

require 'open-uri'
require 'nokogiri'
require 'ruby-progressbar'
require "unicode_utils/display_width"

$BASE_URL = "http://www.songtaste.com"
$SEARCH_URL = "#{$BASE_URL}/search.php?"
$TIME_URL = "#{$BASE_URL}/time.php"
$MUSIC_DIR = File.expand_path '~/Music'

$bold_color_to_code = {
  'gray'=>'1;30',
  'red'=> '1;31',
  'green'=> '1;32',
  'yellow'=> '1;33',
  'blue'=> '1;34',
  'magenta'=> '1;35',
  'cyan'=> '1;36',
  'white'=> '1;37',
  'crimson'=> '1;38',
  'hred'=> '1;41',
  'hgreen'=> '1;42',
  'hbrown'=> '1;43',
  'hblue'=> '1;44',
  'hmagenta'=> '1;45',
  'hcyan'=> '1;46',
  'hgray'=> '1;47',
  'hcrimson'=> '1;48',
}

def color_text(color, *args)
  text = args.join(' ')
  code = $bold_color_to_code.fetch(color.downcase(), '0')
  "\033[#{code}m#{text}\033[0m"
end

$prompt = color_text("green", ">>=") + ' '

class Song
  attr_accessor :name, :href, :rec_num
  def initialize name, href, rec_num
    @name = name.strip
    @href = href
    @rec_num = rec_num
  end
end

def search keyword
  uri = URI($SEARCH_URL)
  params = {:keyword => keyword.encode('gbk')}
  uri.query = URI.encode_www_form(params)
  uri.open.read
end

def get_song_url href
  open("#{$BASE_URL}/#{href}") do |html|
    m = /playmedia1\((.*)\).*Listen/.match(html.read)[-1]
    params = m.gsub('\'', '').split(',').map(&:strip)
    response = Net::HTTP.post_form URI($TIME_URL),
      :str => params[2],
      :sid => params[-2],
      :t => params[-1]
    response.body
  end
end

def parse_search_results response
  song_list = []
  begin
    html = Nokogiri::HTML.parse(response, nil, 'gbk')
    html.css('table.u_song_tab')[0].css('tr').each_with_index do |tr, i|
      song = tr.css('td.singer')[0].css('a')[0]
      song_list << (Song.new song.text, song['href'], tr.css('div.rec_num')[0].text.to_i)
    end
  rescue Exception => e
    puts "#{$prompt}Note: Error occurred when parsing HTML"
  end
  song_list
end

def download_song song_url, song_name
  pbar = nil
  file_name = song_name.gsub(' ', '') + song_url[song_url.rindex('.')..-1]
  File.open File.join($MUSIC_DIR, file_name), 'wb' do |f|
    f.print open(song_url,
                 :content_length_proc => lambda { |t|
                   if t && 0 < t
                     pbar = ProgressBar.create(:title => "#{file_name}",
                                               :total => t,
                                               :format => '%a |%b>>%i| %p%% %e',
                                               :rate_scale => lambda { |rate| rate / 1024 })
                   end
                 },
                 :progress_proc => lambda {|s|
                   pbar.progress = s if pbar
                 }).read
  end
  puts "#{$prompt}Download completed!"
end

def just_name name, display_width
  diff = display_width - UnicodeUtils.display_width(name)
  head = diff / 2
  tail = diff - head
  ' ' * head + name + ' ' * tail
end

def search_and_get_song_list
  song_list = nil
  while true
    print "#{$prompt}Input a search keyword: "
    response = search(STDIN.gets.chomp)
    song_list = parse_search_results response
    if song_list 
      break
    end
    puts (color_text 'red', "No results found!")
  end
  song_list
end

def display_song_list song_list
  column_names = ["ID", "Name", "Popular"]
  widths = []
  widths << [song_list.length.to_s.length, column_names[0].length].max
  widths << [song_list.map { |s| UnicodeUtils.display_width s.name }.max, column_names[1].length].max
  widths << [song_list.map { |s| s.rec_num.to_s.length }.max, column_names[2].length].max

  puts
  column_names = column_names.each_with_index.map { |name, index| just_name(name, widths[index]) }
  puts '| ' + column_names.join(' | ') + ' |'
  puts '|-' + column_names.map { |c| '-' * c.length }.join('-+-') + '-|'
  song_list.each_with_index do |song, index|  
    printf("| %#{widths[0]}d | %s | %#{widths[2]}d |\n",
           index + 1,
           just_name(song.name, widths[1]),
           song.rec_num)
  end
  puts

end

def select_and_download_song song_list
  while true
    print "#{$prompt}Select a song ID [1-#{song_list.length}]: "
    sel_id = STDIN.gets.chomp.to_i - 1
    if (0..song_list.length) === sel_id
      break
    end
    puts (color_text 'red', "Please input a valid song ID!")
  end
  sel_song = song_list[sel_id]

  puts "#{$prompt}Selected song: #{sel_song.name}"
  print "#{$prompt}Retrieving song information..."
  song_url = get_song_url(sel_song.href)
  print "\r"
  puts "#{$prompt}Song URL: #{song_url}"
  download_song song_url, sel_song.name  
end

song_list = search_and_get_song_list
display_song_list song_list
select_and_download_song song_list 
