#!/bin/env ruby
require_relative 'othacks.rb'

def p name, dir
  size = Dir.wavs(dir).size
  name.match(/new/) ? new = true : new = false
  name.match(/sub/) ? sub = true : sub = false
  t = "#" unless size < 24 or size > 64 or new
  t = "+" if size < 24 and !new
  t = "-" if size > 64 and !new 
  puts "#{t}#{name}: #{size}" unless (new or sub) and size == 0
end

@chains.each do |d|
  p d, File.join(@basedir, d)
end

@projects.each do |d|
  pdir = File.join @basedir, d
  p "#{d} new", pdir
  @instruments.each do |i|
    p"#{d} #{i}", File.join(pdir, i)
  end
end
