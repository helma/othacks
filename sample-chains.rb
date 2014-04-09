#!/bin/env ruby
require 'fileutils'
require_relative 'converter.rb'

converter = Converter.new ARGV[0], "-d vamp:qm-vamp-plugins:qm-similarity"

converter.check
converter.analyze
converter.sort
converter.select
converter.render_chain