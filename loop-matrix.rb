#!/bin/env ruby
require 'fileutils'
require_relative 'converter.rb'
require 'csv'

converter = Converter.new ARGV[0], "-d vamp:qm-vamp-plugins:qm-similarity"

converter.analyze
converter.sort
converter.select
converter.render_matrix
converter.render_chain
