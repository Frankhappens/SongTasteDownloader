#! /usr/bin/env ruby 
#-*- coding: utf-8 -*-
# Author: qjp
# Date: <2014-09-11 Thu>

require 'open-uri'
require 'nokogiri'
require 'progressbar'
require "unicode_utils/display_width"

$BASE_URL = "http://www.songtaste.com"
$SEARCH_URL = "#{$BASE_URL}/search.php?"
$TIME_URL = "#{$BASE_URL}/time.php"
$MUSIC_DIR = File.expand_path '~/tmp'

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
    params = m.gsub('\'', '').split(',').map { |item| item.strip }
    response = Net::HTTP.post_form URI($TIME_URL),
      :str => params[2],
      :sid => params[-2],
      :t => params[-1]
    response.body
    # params
  end
end

def parse_search_results response
  html = Nokogiri::HTML.parse(response, nil, 'gbk')
  song_list = []
  html.css('table.u_song_tab')[0].css('tr').each_with_index do |tr, i|
    song = tr.css('td.singer')[0].css('a')[0]
    song_list << (Song.new song.text, song['href'], tr.css('div.rec_num')[0].text.to_i)
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
                     pbar = ProgressBar.new("", t)
                     pbar.file_transfer_mode
                   end
                 },
                 :progress_proc => lambda {|s|
                   pbar.set s if pbar
                 }).read
  end
  puts "Download completed!"
end

print "Input a search keyword: "
response = search(STDIN.gets.chomp)
song_list = parse_search_results response
id_width = song_list.length.to_s.length
name_width = song_list.map { |s| s.name.length }.max
rec_num_width = song_list.map { |s| s.rec_num.to_s.length }.max
song_list.each_with_index do |song, id|
  # printf "%#{id_width}d: %#{name_width}s, %#{rec_num_width}d\n", id,
  # song.name, song.rec_num
  puts "#{id}: #{song.name}, #{song.rec_num}"
end
  

print "Pleaes input a song id: "
sel_id = STDIN.gets.chomp.to_i - 1
sel_song = song_list[sel_id]

song_url = get_song_url(sel_song.href)
download_song song_url, sel_song.name
