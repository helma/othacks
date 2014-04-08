#!/bin/env ruby
require 'yaml'
require_relative 'array.rb'

root = "/media/ot/ISS/AUDIO/waveforms/AKWF_transposed"

output = {}
Dir[File.join(root,"*")].each do |d|
  Dir.chdir d
  1.step(5,2).each do |n|
    all = Dir[File.join(d,"*C#{n}*")]
    nr = all.size
    if nr >= 128
      filename = "#{d}C#{n}64"
      selection = all.pare 128
      output["#{d}AC#{n}_64.wav"] = selection[0..63]
      output["#{d}BC#{n}_64.wav"] = selection[64..127]
    elsif nr >= 64
      output["#{d}C#{n}_64.wav"] = all.pare 64
    elsif nr >= 48
      output["#{d}C#{n}_48.wav"] = all.pare 48
    elsif nr >= 32
      output["#{d}C#{n}_32.wav"] = all.pare 32
    elsif nr >= 16
      output["#{d}C#{n}_16.wav"] = all.pare 16
    elsif nr >= 8
      output["#{d}C#{n}_8.wav"] = all.pare 8
    else
    #elsif nr >= 4
      output["#{d}C#{n}_4.wav"] = all.pare 4
    end
  end
end

output.each do |filename,files|
  puts `sox #{files.join ' '} #{filename.sub(/AKWF_transposed/,'AKWFchains').sub(/AKWF_/,'')}`
end
#puts output.to_yaml
