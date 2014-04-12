#!/bin/env ruby
require 'fileutils'
require 'csv'

class Sample

  attr_accessor :original, :name, :norm, :mono, :slices

  def initialize file
    @original = file
    @name = File.basename(@original)
    @tmp = "/tmp/ot/#{File.basename(File.dirname(@original))}"
    @norm = File.join @tmp, "norm", @name
    @mono = File.join @tmp, "mono", @name
    @simdir = File.join @tmp, "sim"
    [File.join(@tmp, "norm"), File.join(@tmp, "mono"), @simdir].each{|d| FileUtils.mkdir_p d}
  end

  def bpm
    start_bpm = 44100*60.0/nr_samples
    n = 1
    while n*start_bpm < 90
      n*=2
    end
    n*start_bpm
  end

  def nr_slices
    bpm = start_bpm = 44100*60.0/nr_samples
    n = 1
    while bpm < 90
      bpm = n*start_bpm
      n*=2
    end
    2*n # not sure why 2 is needed, stereo files?
  end

  def slice
    @slices = []
    length = nr_samples/nr_slices
    start = 0
    16.times do |i|
      dir = File.join @tmp, "slice", i.to_s
      FileUtils.mkdir_p dir
      file = File.join dir, @name
      `sox #{@norm} #{file} trim #{start}s #{length}s` unless File.exists? file
      @slices << file
      start += length
    end
  end

  def normalize # TODO same perceived loudness
    `sox --norm #{@original} #{@norm}` unless File.exists?(@norm)
  end

  def to_mono
    normalize
    `sox #{@norm} #{@mono} remix 1,2` unless File.exists?(@mono)
  end

  def nr_samples 
    `soxi #{@original} |grep Duration|cut -d '=' -f2|sed  's/samples//'|tr -d " "`.to_i
  end

  def similarity sample, vamp
    f1 = File.basename self.norm
    f2 = File.basename sample.norm
    simfiles = [File.join(@simdir, "#{f1}-#{f2}.sim"), File.join(@simdir, "#{f2}-#{f1}.sim")]
    if self == sample
      1.0
    elsif File.exists? simfiles.first 
      File.read(simfiles.first).to_f
    else
      self.to_mono
      sample.to_mono
      comparison = File.join @simdir, "#{f1}-#{f2}.wav"
      `sox -M #{self.mono} #{sample.mono} #{comparison}` unless File.exists?(comparison)
      result = `/home/ch/src/sonic-annotator-1.0-linux-amd64/sonic-annotator -t ./#{vamp}.n3 -w csv --csv-stdout  #{comparison} 2>/dev/null`
      sim = result.split("\n").first.split(",")[3].to_f
      simfiles.each{|n| File.open(n,"w+"){|f| f.print sim}}
      sim
    end
  end

  def split_bars
    dir = File.dirname(@original)
    bak_dir = File.join dir, "bak"
    FileUtils.mkdir_p bak_dir
    n = nr_slices/16
    bars = []
    unless n == 1
      length = nr_samples/n
      start = 0
      n.times do |i|
        barname = "#{File.basename(@original,".wav")}_bar#{i+1}.wav"
        barfile = File.join dir, barname
        `sox #{@original} #{barfile} trim #{start}s #{length}s` unless File.exists? barfile
        bars << barfile
        start += length
      end
    end
    FileUtils.mv @original, bak_dir
    bars.collect{|f| Sample.new f}
  end

end

