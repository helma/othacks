#!/bin/env ruby
require_relative 'converter.rb'
require_relative 'project.rb'

converter = Converter.new ARGV[0], "timbre-rhythm"

converter.split_bars
converter.normalize
converter.similarity
converter.sort
files = converter.matrix

if ARGV[1]
  p=Project.new ARGV[1]
  p.remove_samples ARGV[0]
  p.add_matrix files
  p.save
end
