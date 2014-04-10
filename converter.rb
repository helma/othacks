#!/bin/env ruby
require 'fileutils'
require 'csv'

class Converter

  def initialize dir, vamp="-d vamp:qm-vamp-plugins:qm-similarity" # Timbre similarity by default
    @dir = dir
    @samples = Dir[File.join(@dir,"*.wav")]
    @name = File.basename(@dir)
    @tmp = "/tmp/ot/#{@name}"
    @normdir = File.join @tmp, "norm"
    @monodir = File.join @tmp, "mono"
    @simdir = File.join @tmp, "sim"
    @simfile = File.join(@simdir,"sim.csv")
    @slicedir = File.join @tmp, "slice"
    [@normdir,@monodir,@simdir,@slicedir].each{|d| FileUtils.mkdir_p d}
    @vamp = vamp
  end

  def nr_samples file
    `soxi #{file} |grep Duration|cut -d '=' -f2|sed  's/samples//'|tr -d " "`.to_i
  end

  def nr_slices file
    #`soxi #{file} |grep Duration|cut -d '=' -f1|cut -d ':' -f2-|tr -d " "`
    nr_samples(file)/44100.0
  end

  def check
    puts "checking samples in #{@dir}"
    sizes = @samples.collect{|f| nr_samples f}.uniq
    exit "unequal sample sizes #{sizes.inspect}" unless sizes.size == 1
    @length = sizes.first
  end

  def analyze 
    puts "analyzing and normalizing samples in #{@dir}"
    @norm_samples = []
    mono_samples = []
    File.exists?(@simfile) ? @similarities = CSV.read(@simfile,{:converters => [:float]}) : @similarities = []
    @samples.each_with_index do |f,i|
      norm = File.join @normdir, File.basename(f)
      @norm_samples << norm
      `sox --norm #{f} #{norm}` unless File.exists?(norm) # TODO same perceived loudness
      unless File.exists?(@simfile)
        mono = File.join @monodir, File.basename(f) 
        `sox #{norm} #{mono} remix 1,2` unless File.exists?(mono)
        @similarities << []
        @similarities[i][i] = 1.0
        mono_samples.each_with_index do |m,j|
          comparison = File.join @simdir,  "#{i}-#{j}.wav"
          `sox -M #{mono} #{m} #{comparison}` unless File.exists?(comparison)
          result = `/home/ch/src/sonic-annotator-1.0-linux-amd64/sonic-annotator #{@vamp} -w csv --csv-stdout  #{comparison} 2>/dev/null`
          sim = result.split("\n").first.split(",")[3].to_f # TODO check for "Rhythm and Timbre"
          @similarities[i][j] = sim.to_f
          @similarities[j][i] = sim.to_f
        end
        mono_samples << mono
      end
    end
    CSV.open(@simfile,"w+") do |csv| 
      @similarities.each{|row| csv << row}
    end
  end

  def select
    nr = case @norm_samples.size
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
         else exit("cannot process #{@norm_sample.size} samples")
         end
    puts "selecting #{nr} from #{@norm_samples.size} samples"
    # remove most similar samples
    minsim = @similarities.collect{|s| s.min} #  similarity
    (@norm_samples.size - nr).times do
      i = minsim.index minsim.min
      @norm_samples.delete_at i
      minsim.delete_at i
      @similarities.delete_at i
      @similarities.each{|s| s.delete_at i}
    end
    @simfile = File.join(@simdir,"select_sim.csv")
    CSV.open(@simfile,"w+") do |csv| 
      @similarities.each{|row| csv << row}
    end
  end

  def sort
    puts "sorting samples"
    idx = `./seriation.R #{@simfile}`.split(/\s+/).collect{|i| i.to_i-1}
    @norm_samples = idx.collect{|i| @norm_samples[i]}
  end

  def render_chain
    chain_dir = File.join @dir, "chain"
    FileUtils.mkdir_p chain_dir
    chain = File.join chain_dir, "#{File.basename(@dir)}_#{@norm_samples.size}.wav"
    puts "rendering #{chain}"
    `sox #{@norm_samples.join ' '} #{chain}`
  end

  def render_matrix
    slice_length = @length/@selected_samples.size
    slices = []
    # get slice number
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

