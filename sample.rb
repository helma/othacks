#!/bin/env ruby
require 'fileutils'
require 'ruby-audio'
require 'matrix'
require 'digest/md5'

class Sample 

  attr_reader :path, :dir, :channels, :samplerate, :seconds, :frames, :max_amplitude, :slices
  def initialize path
    @path = path
    @dir = File.dirname(path)
    update
  end

  def update
    RubyAudio::Sound.open(@path) do |snd|
      @channels = snd.info.channels
      @samplerate = snd.info.samplerate
      @seconds = snd.info.length
      @frames = snd.info.frames
    end
    stat = Hash[`sox "#{@path}" -n stat 2>&1|sed '/Try/,$d'`.split("\n")[0..14].collect{|l| l.split(":").collect{|i| i.strip}}]
    @max_amplitude = [stat["Maximum amplitude"].to_f,stat["Minimum amplitude"].to_f.abs].max
    @mfcc = nil # calculate on demand
    @bpm = bpm
  end

  def play
    `play #{@path} 2>&1 >/dev/null`
  end

  def svg

    svg_file = File.join "/tmp/ot",@path.sub(/wav(.*)/i,'svg\1')
    FileUtils.mkdir_p File.dirname(svg_file)
    #`gnuplot -e "title='#{sample.path}'; set terminal svg; set output '#{s.svg_file}'; set xrange [0:#{max_sec}]" -p ./plot`
    `sox #{@path} /tmp/gnuplot.dat; gnuplot -e "title='#{@path}'; set term svg; set output '#{svg_file}'" -p ./plot`
    svg_file
  end

  def show
    pid = fork {`sox #{@path} /tmp/gnuplot.dat; gnuplot -e "title='#{@path}'; set term X11" -p ./plot`}
    Process.detach pid
  end

  def select message
    show
    play
    puts message + " (y/n)?"
    case STDIN.gets
    when /^y/i
      true
    when /^n/i
      false
    else
      select message
    end
  end

  def backup 
    bakdir = File.join "/tmp/ot", @dir, "bak"
    date = `date +\"%Y%m%d_%H%M%S\"`.chomp
    bakfile = File.join bakdir, name+"."+date
    FileUtils.mkdir_p bakdir
    FileUtils.cp @path, bakfile
    bakfile
  end

  def bars= b
    times = b/self.bars
    unless times == 1
      if times > 1 and times == times.to_i
        puts "!!"
      puts [@path, times, self.bars, @bpm].join(" ")
        bak = backup
        input = ""
        times.to_i.times{ input += "'#{bak}' "}
        `sox #{input} "#{@path}"`
        update
      elsif times < 1 and (1/times) == (1/times).to_i
        length = (@frames*times).to_i
        bak = backup
        (0..(1/times).to_i-1).each do |i|
          file = @path.sub(/\.wav/i,"_#{i}.wav")
          `sox "#{bak}" -b 24 "#{file}" trim #{i*length}s #{length}s`
        end
        FileUtils.mv @path, File.dirname(bak)
        puts "#{@path} split into #{1/times} files. recollect samples!"
      else
        puts "#{@path}: cannot convert #{self.bars} to #{b} bars"
      end
    end
  end

  def mono2stereo
    unless @channels == 2
      bak = backup
      `sndfile-interleave "#{bak}" "#{bak}" -o "#{@path}"`
      update
    end
  end

  def trim_seconds sec
    unless @seconds <= sec
      `sox "#{backup}" -b 24 "#{@path}" trim 0 #{sec}`
      update
    end
  end

  def trim_silence
    start = `aubioquiet -i "#{@path}"|grep QUIET|sed 's/QUIET: //'`.split("\n").last
    trim_seconds(start.to_f+0.05) if start
  end

  def pad length
    unless @frames >= length 
      `sox  "#{backup}" -b 24 "#{@path}" pad #{length - @frames}s@#{@frames}s`
      update
    end
  end

  def name
    File.basename(@path)
  end

=begin
  # http://rubymonk.com/learning/books/4-ruby-primer-ascent/chapters/45-more-classes/lessons/105-equality_of_objects
  def hash
    self.md5.hash
  end

  def eql? sample
    md5 == sample.md5
  end

  def == sample
    eql? sample
  end
=end

  def md5
    Digest::MD5.file(@path).to_s
  end

  def bpm= b
    unless self.bpm == b
      factor = @seconds/(bars.round*4*60/b.to_f)
      `sox  "#{backup}" -b 24 "#{@path}" tempo #{factor}`
      update
    end
  end

  def pitch
    input = `aubionotes -v -u midi  -i #{@path} 2>&1 |grep "^[0-9][0-9].000000"|sed 's/read.*$//'`.split("\n")
    input.empty? ? nil : input.first.split("\t").first.to_i  # only onset pitch
  end

  def bpm
    bpm = 44100*60.0/@frames
    n = 1
    while n*bpm < 90 
      n*=2 
    end
    n*bpm
  end

  def bars
    @seconds*@bpm/60/4
  end

  def normalized?
    @max_amplitude > 0.99
  end

  def normalize
    unless normalized?
      `sox --norm "#{backup}" -b 24 "#{@path}"`
      update
    end
  end

  def wavegain
    #backup
    #puts `cd #{@dir}; wavegain -c #{@path}`
    #update
  end

  def mfcc
    # remove first column with timestamps
    # remove second column with energy
    @mfcc ||= Vector.elements(`aubiomfcc "#{@path}"`.split("\n").collect{|l| l.split(" ")[2,12].collect{|i| i.to_f}}.flatten)
  end

  def zerocrossings
    snd = RubyAudio::Sound.open @path
    snd.seek 0
    buf = snd.read(:float, snd.info.frames)
    i = buf.size-2
    while i >= 0 and (buf[i][0]*buf[i+1][0] < 0 or buf[i][1]*buf[i+1][1] < 0) # get first zero crossing of both channels
      i-=1
    end
    puts i
  end

  def similarity sample # cosine
    begin
    mfcc.inner_product(sample.mfcc)/(mfcc.magnitude*sample.mfcc.magnitude)
    rescue
      puts @path, @seconds, sample.path, sample.seconds
      puts $!
      0
    end
  end

  def chop
    chopdir = File.join(@dir,"chops")
    FileUtils.mkdir_p chopdir
    puts `aubiocut -c -i "#{@path}" -o #{chopdir}`
=begin
    onsets = `aubioonset #{@path}`.split("\n").collect{|t| t.to_f}
    onsets << @seconds
    onsets[0,onsets.length-1].each_with_index do |o,i|
      chop = File.join chopdir, "#{File.basename(@path,".wav")}-#{i}.wav"
      puts chop
      #puts "#{o} #{onsets[i+1]-o}" 
      `sox "#{@path}" "#{chop}" trim #{o} #{onsets[i+1]-o}` 
    end
    onsets
=end
  end

  def slice nr=16 #TODO missing samples due to rounding errors, zero crossings
    @slices = []
    length = (frames/nr.to_f).round
    start = 0
    nr.times do |i|
      dir = File.join "/tmp/ot/",@dir,"slice", i.to_s
      FileUtils.mkdir_p dir
      slice = File.join dir, name
      `sox "#{@path}" "#{slice}" trim #{start}s #{length}s` unless File.exists? slice
      @slices << slice
      start += length
    end
  end

  def self.silence frames
    file = File.join "/tmp", "silence.wav"
    `sox -n -r 44100 -b 24 -c 2 "#{file}" trim 0 #{frames/44100.0}` # wrong number of samples with sample durations
    file
  end

end
