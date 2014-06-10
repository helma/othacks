#!/usr/bin/env ruby
require 'time'
require_relative 'othacks.rb'

dir = ARGV[0]
c = Collection.new(ARGV[0])
c.prepare
c.review_duplicates
c = Collection.new(ARGV[0])
c.prepare
c.review
