#!/bin/env ruby
require 'fileutils'
require_relative 'converter.rb'

converter = Converter.new ARGV[0], "-d vamp:qm-vamp-plugins:qm-similarity"

converter.check
converter.analyze
converter.select
converter.sort
converter.render_chain
