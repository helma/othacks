#!/bin/env ruby
require_relative 'converter.rb'
require_relative 'project.rb'

converter = Converter.new ARGV[0], "timbre-rhythm"

converter.check_bpms
converter.split_bars
converter.normalize
converter.similarity
converter.sort
files = converter.matrix

if ARGV[1]
  p=Project.new ARGV[1]
  p.remove_samples files
  p.add_matrix files
  p.save
  #puts p.to_s
end
=begin
=end
