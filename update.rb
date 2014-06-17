#!/bin/env ruby
require_relative 'othacks.rb'

chain_files = [] 
@chains.each do |d|
  puts d
  chain_files << Dir[File.join(@basedir, d,"chain","#{d}_*wav")].sort_by{|f| File.mtime(f)}.last
  #c = Collection.new(File.join @basedir, d)
  #c.prepare
  #chain_files << c.to_chain
end
chain_files.compact!

@projects.each do |d|
  pdir = File.join @basedir, d
  project = Project.new pdir
  project.samples = []
  @instruments.each do |i|
    dir = File.join pdir, i
    if File.directory?(dir)
      puts dir
      #c = Collection.new(dir)
      #c.prepare
      c = Collection.new(dir)
      case i
      when "drums"
        #matrix_dir = File.join dir, "matrix"
        #project.add_matrix matrix_dir
        project.add_matrix c.to_matrix
      when "music", "sub"
        #chain = Dir[File.join(dir, "chain", "music_*wav")].first
        #puts chain
        #project.add_chain chain
        project.add_chain c.to_chain
      end
    end
  end
  chain_files.each do |f|
    project.add_chain f
  end
  project.save
  #puts project.to_s
end
=begin
=end
