#!/bin/env ruby
require_relative 'converter.rb'

converter = Converter.new ARGV[0], "timbre"

converter.ensure_equal_size
converter.normalize
converter.similarity
converter.select :min
converter.sort
converter.chain
