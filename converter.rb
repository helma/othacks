#!/bin/env ruby
require 'fileutils'
require 'csv'

# remove size equally spaced elements from array
# http://stackoverflow.com/questions/5250285/how-to-remove-equally-spaced-elements-from-an-array-with-length-of-n-to-match
# Alternative:
# http://stackoverflow.com/questions/5250285/how-to-remove-equally-spaced-elements-from-an-array-with-length-of-n-to-match
class Array
  def pare size
    new = Array.new size
    n2 = self.length - 2
    m2 = size - 2
    new[0] = self[0]
    i = 0
    j = 0
    while (j < n2) do
      diff = (i+1)*n2 - (j+1)*m2
      if (diff < n2/2)
        i += 1
        j += 1
        new[i] = self[j]
      else
        j += 1
      end
    end
    new[m2+1] = self[n2+1]
    new
  end
end

class Converter

  def initialize dir, vamp="-d vamp:qm-vamp-plugins:qm-similarity" # Timbre similarity by default
    @dir = dir
    @samples = Dir[File.join(@dir,"*.wav")]
    @name = File.basename(@dir)
    @tmp = "/tmp/ot/#{@name}"
    @normdir = File.join @tmp, "norm"
    @monodir = File.join @tmp, "mono"
    @simdir = File.join @tmp, "sim"
    @slicedir = File.join @tmp, "slice"
    [@normdir,@monodir,@simdir,@slicedir].each{|d| FileUtils.mkdir_p d}
    @vamp = vamp
  end

  def nr_samples file
    `soxi #{file} |grep Duration|cut -d '=' -f2|sed  's/samples//'|tr -d " "`.to_i
  end

  def check
    puts "check ..."
    sizes = @samples.collect{|f| nr_samples f}.uniq
    exit "unequal sample sizes #{sizes.inspect}" unless sizes.size == 1
    @length = sizes.first
  end

  def analyze 
    puts "analyze ..."
    @norm_samples = []
    mono_samples = []
    @similarities = []
    @samples.each_with_index do |f,i|
      norm = File.join @normdir, File.basename(f)
      mono = File.join @monodir, File.basename(f) 
      @norm_samples << norm
      `sox --norm #{f} #{norm}` unless File.exists?(norm)
      `sox #{norm} #{mono} remix 1,2` unless File.exists?(mono)
      @similarities << []
      @similarities[i][i] = 1.0
      mono_samples.each_with_index do |m,j|
        comparison = File.join @simdir,  "#{i}-#{j}.wav"
        `sox -M #{mono} #{m} #{comparison}` unless File.exists?(comparison)
        result = `/home/ch/src/sonic-annotator-1.0-linux-amd64/sonic-annotator #{@vamp} -w csv --csv-stdout  #{comparison} 2>/dev/null`
        sim = result.split("\n").first.split(",")[3].to_f # TODO check for "Rhythm and Timbre"
        @similarities[i][j] = sim
        @similarities[j][i] = sim
      end
      mono_samples << mono
    end
    File.open(File.join(@simdir,"sim.csv"),"w+"){|f| f.puts @similarities.collect{|s| s.join ", "}.join("\n") }
  end

  def sort
    puts "sort ..."
    idx = `./seriation.R #{@simdir}`.split(/\s+/).collect{|i| i.to_i-1}
    @sorted_samples = idx.collect{|i| @norm_samples[i]}
  end

  def select
    puts "select ..."
    # TODO prioritize removal of samples with high similarity
    nr = case @sorted_samples.size
         when 2 then 2
         when 3 then 3
         when 4..5 then 4
         when 6..7 then 6
         when 8..11 then 8
         when 12..15 then 12
         when 16..23 then 16
         when 24..31 then 24
         when 32..47 then 32
         when 48..63 then 48
         when 64..127 then 64
         else exit("cannot process #{@sorted_sample.size} samples")
         end
    @selected_samples = @sorted_samples.pare nr
  end

  def render_chain
    puts "render ..."
    chain = File.join @dir, "chain", "#{File.basename(@dir)}_#{@selected_samples.size}.wav"
    `sox #{@selected_samples.join ' '} #{chain}`
  end

  def render_matrix
    slice_length = @length/@selected_samples.size
    slices = []
    # split samples
    @selected_samples.each do |f|
      slices << []
      @selected_samples.size.times do |s| # TODO check!!
        name = File.join @slicedir, File.basename(f,".wav")+"-#{s}.wav"
        `sox #{f} #{name} trim #{s*slice_length}s #{(s+1)*slice_length}s`
        slices.last << name
      end
    # concatenate samples
    end
    @selected_samples.size.times do |s|
      name = File.join @slicedir, File.basename(f,".wav")+"-#{"%03d" % s}.wav"
    end

  end

end

