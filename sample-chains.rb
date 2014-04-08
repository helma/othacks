#!/bin/env ruby
require 'fileutils'
require_relative 'array.rb'
require 'csv'

norm_samples = []
mono_samples = []
name = File.basename(ARGV[0])
tmp = "/tmp/ot/#{name}"
similarities = []
FileUtils.mkdir_p tmp
samples = select_samples(ARGV[0])
samples.each_with_index do |f,i|
  norm = File.join tmp, File.basename(f,".wav") + "norm.wav"
  mono = File.join tmp, File.basename(f,".wav") + "mono.wav"
  norm_samples << norm
  `sox --norm #{f} #{norm}`
  #`sox --norm #{f} #{norm} silence 1 0.1 1%`
  `sox #{norm} #{mono} remix 1,2`
  similarities << []
  similarities[i][i] = 1.0
  mono_samples.each_with_index do |m,j|
    comparison = File.join tmp,  "#{i}-#{j}.wav"
    `sox -M #{mono} #{m} #{comparison}`
    result = `/home/ch/src/sonic-annotator-1.0-linux-amd64/sonic-annotator -d vamp:qm-vamp-plugins:qm-similarity -w csv --csv-stdout  #{comparison} 2>/dev/null` # Timbre similarity by default
    sim = result.split("\n").first.split(",")[3].to_f
    similarities[i][j] = sim
    similarities[j][i] = sim
  end
  mono_samples << mono
end
chain = File.join ARGV[0], "#{File.basename(ARGV[0])}_#{norm_samples.size}.wav"
File.open(File.join("/tmp/ot","sim.csv"),"w+"){|f| f.puts similarities.collect{|s| s.join ", "}.join("\n") }
idx = `./seriation.R`.split(/\s+/).collect{|i| i.to_i-1}
sorted_samples = idx.collect{|i| norm_samples[i]}
`sox #{sorted_samples.join ' '} #{chain}`
