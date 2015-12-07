#!/bin/env ruby
require 'csv'
require 'gtk2'
require 'waveform'
require_relative 'sample.rb'

GREEN = Gdk::Color.parse("green")
BLUE = Gdk::Color.parse("blue")
RED = Gdk::Color.parse("red")
YELLOW = Gdk::Color.parse("yellow")
BLACK = Gdk::Color.parse("black")
WHITE = Gdk::Color.parse("white")
GREY = Gdk::Color.parse("grey")

class Gdk::Pixbuf
  def adjust(tw,th)
    ratio = 0.97*[tw/self.width, th/self.height].min
    self.scale(self.width*ratio, self.height*ratio)
  end
end

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

def Dir.wavs dir
  Dir.glob(File.join(dir,"*wav"), File::FNM_CASEFOLD)
end

class Collection < Array

  def initialize path=nil
    if path
      @dir = path
      super Dir.wavs(path).collect{|f| Sample.new f}
      remove_duplicates
    else
      super []
    end
  end

  def remove_duplicates
    self.duplicates.each do |dups|
      keep = dups.shift
      dups.each do |dup|
        self.delete_at self.rindex(dup)
        unless keep.path == dup.path
          puts "deleting #{dup.path}, duplicate of #{keep.path}"
          dup.backup
          FileUtils.rm dup.path
        end
      end
    end
    self
  end

  def duplicates
    self.group_by {|e| e.md5}.select {|k, v| v.size > 1}.values
  end

  def bpm
    @dir.split('/').grep(/\d\d\d/).first.to_i
  end

  def check_loops
    each do |s|
      puts "#{s.path}: bpm: #{s.bpm}, bars: #{s.bars}" unless s.bpm == bpm and s.bars == 2 
    end
    puts "proceed? (y/n)"
    case STDIN.gets
    when /^n/i
      abort
    end
  end

  def prepare
    loop? ? prepare_loops : prepare_singles
  end

  def prepare_loops
    each do |s|
      s.mono2stereo # make stereo files
      s.normalize
      s.bpm = bpm
      s.bars = 2
    end
    simsort!
  end

  def prepare_singles
    max_frames = collect{|s| s.frames_without_silence}.max
    each do |s|
      s.mono2stereo
      s.normalize
      s.frames = max_frames
    end
    simsort!
  end

  def to_chain
    simsort!
    chain_dir = File.join @dir, "chain"
    FileUtils.mkdir_p chain_dir
    files = collect{|s| s.path}
    files = files.pare 64 if files.size > 64
    frames = collect{|s| s.frames}.uniq
    abort "uneqal sample sizes" unless frames.size == 1
    silence = Sample.silence(frames.first)
    until [2,4,8,12,16,24,32,48,64].include? files.size
      files << silence
    end
    name = File.basename(@dir)
    chain = File.join chain_dir, "#{name}_#{files.size}.wav"
    puts "rendering #{chain}"
    `sox "#{files.join '" "'}" -b 24 "#{chain}"`
    chain
  end

  def to_matrix
    simsort!
    each{|s| s.slice 16}
    matrix_dir = File.join @dir, "matrix"
    FileUtils.mkdir_p matrix_dir
    silence = Sample.silence(self.first.frames/16) # pad with silence
    name = File.basename(@dir)
    16.times do |i|
      slices = collect{|s| s.slices[i]}
      slices = slices.pare 64 if slices.size > 64
      until [2,4,8,12,16,24,32,48,64].include? slices.size 
        slices << silence # pad with silence
      end
      matrix = File.join matrix_dir, "#{name}#{"%03d" % (i+1).to_s}_#{slices.size}.wav"
      puts "rendering #{matrix}"
      `sox "#{slices.join '" "'}" -b 24 "#{matrix}"`
    end
    File.open(File.join(matrix_dir,"#{name}_matrix.txt"),"w+"){|f| f.puts collect{|s| s.name}.join("\n")}
    matrix_dir
  end

  def dissimilarity_matrix
    unless @dissimilarity_matrix 
      @dissimilarity_matrix = []
      self.each_with_index do |s,i|
        @dissimilarity_matrix << []
        @dissimilarity_matrix[i][i] = 0
        self[0..i-1].each_with_index do |s2,j|
          sim = s.similarity s2
          sim = 1 if sim > 1 # rounding errors?
          @dissimilarity_matrix[i][j] = 1-sim
          @dissimilarity_matrix[j] ||= []
          @dissimilarity_matrix[j][i] = 1-sim
        end
      end
    end
    @dissimilarity_matrix
  end

  def duplicate_candidates threshold=0.02
    duplicate_candidates = []
    dissimilarity_matrix.each_with_index do |row,i|
      candidates = Collection.new
      row.each_with_index do |sim,j|
        candidates << self[j] if sim < threshold
      end
      duplicate_candidates << candidates if candidates.size > 1 
    end
    duplicate_candidates.uniq
  end

  def review_duplicates
    duplicate_candidates.each { |d| d.review }
  end

  def simsort!
    clusters = []
    cands = duplicate_candidates(0.15)
    others = self - cands.flatten.uniq
    cands.each_with_index do |d,i|
      cluster_idx = nil
      clusters.each_with_index do |c,n|
        cluster_idx = n unless (c&d).empty?
      end
      cluster_idx ? cluster = clusters[cluster_idx] : cluster = d
      cands[i+1,cands.size-i+1].each do |d2|
        unless (cluster & d2).empty?
          cluster += d2
        end
      end
      cluster_idx ? clusters[cluster_idx] = cluster.uniq : clusters << cluster.uniq
    end
    clusters.collect!{|c| c.uniq.size > 2 ? seriate(c.uniq) : c.uniq }
    clusters << seriate(others.uniq)
    clusters = (clusters + others.collect{|s| [s]}).flatten
    sort!{|a,b| clusters.index(a) <=> clusters.index(b)}
  end

=begin
  def simsort!
    FileUtils.mkdir_p "/tmp/ot/"
    simfile = "/tmp/ot/similarities.csv"
    CSV.open(simfile,"w+") do |csv|
      dissimilarity_matrix.each{|row| csv << row}
    end 
    idx = `#{File.join __dir__,"seriation.R"} #{simfile}`.split(/\s+/).collect{|i| i.to_i-1}
    sort!{|a,b| idx[index(a)] <=> idx[index(b)]}
  end
=end

  def seriate samples
    FileUtils.mkdir_p "/tmp/ot/"
    simfile = "/tmp/ot/similarities.csv"
    CSV.open(simfile,"w+") do |csv|
      samples.each do |s|
        csv << samples.collect{|s2| 1-s.similarity(s2)}
      end
    end 
    idx = `#{File.join __dir__,"seriation.R"} #{simfile}`.split(/\s+/).collect{|i| i.to_i-1}
    idx.collect{|i| samples[i]}
  end

  def loop?
    @dir ||= collect{|s| File.dirname s.path}.uniq.first
    @dir.match(%r{/\d\d\d}) ? true : false
  end

  def review

    FileUtils.rm Dir[File.join("/tmp/ot",@dir,"*png")] if @dir

    @keep = []
    @delete = []
    @move = []

    @cols = 8
    @rows = (self.size/@cols.to_f).ceil
    @current = 0
    @win = Gtk::Window.new
    @win.modify_bg(Gtk::STATE_NORMAL,BLACK)

    @table = Gtk::Table.new(@rows,@cols,true)
    @frames = []
    @tw = 0.99*@win.screen.width/@cols
    @th = 0.97*@win.screen.height/@rows

    @rows.times do |r|
      @cols.times do |c|
        frame = Gtk::Frame.new
        frame.modify_bg(Gtk::STATE_NORMAL,BLACK)
        image = Gtk::Image.new 
        frame.add image
        @table.attach frame, c, c+1, r, r+1
        @frames << frame
      end
    end

    @win.add(@table)

    @win.signal_connect("key-press-event") do |w,e|
      case Gdk::Keyval.to_name(e.keyval)
      when "q"
        quit
      when /^h$|Left/
        goto -1
      when /^l$|Right/
        goto 1
      when /^j$|Down/
        goto @cols
      when /^k$|Up/
        goto -1*@cols
      when "e"
        @player.quit
        `sweep "#{self[@current].path}"`
        @player = Player.new self[@current], loop?
      when "s"
        save
      when "space"
        @player.pause
      when "Return"
        keep 
      when "BackSpace"
        remove
      when "backslash"
        move
      else
        puts '"'+Gdk::Keyval.to_name(e.keyval)+'"'
      end
    end

    @win.signal_connect("destroy") { quit }
    @win.show_all
    draw
    goto 0
    Gtk.main
  end

  private
  def save
    @delete.each do |s|
      dir = File.join s.dir, "delete"
      FileUtils.mkdir_p dir
      FileUtils.mv s.path, dir
      delete s
    end
    @move.each do |s|
      dir = File.join s.dir, "move"
      FileUtils.mkdir_p dir
      FileUtils.mv s.path, dir
      delete s
    end
    quit
  end

  def keep
    @delete.delete self[@current] 
    @move.delete self[@current]
    @keep << self[@current]
    goto 1
  end

  def remove
    @keep.delete self[@current]
    @move.delete self[@current]
    @delete << self[@current]
    goto 1
  end

  def move
    @delete.delete self[@current]
    @keep.delete self[@current]
    @move << self[@current]
    goto 1
  end

  def quit
    @player.quit
    Gtk.main_quit
  end

  def goto n
    @current = (@current+n) % self.size
    puts self[@current].path
    @player ||= Player.new self[@current], loop?
    @player.play self[@current]
    draw
  end

=begin
  def play
    @player.file = self[@current].path 
  end
=end

  def draw
    if (@keep+@delete+@move).collect{|s| s.path}.sort == self.collect{|s| s.path}.sort
      save
    else
      n = 0
      @frames.each do |frame|
        frame.modify_bg(Gtk::STATE_NORMAL,BLACK)
        if self[n]
          wave = File.join "/tmp/ot",self[n].path.sub(/wav(.*)/i,'png\1')
          FileUtils.mkdir_p File.dirname(wave)
          Waveform.generate self[n].path, wave, :width => @tw.round, :height => @th.round, :force => true unless File.exist? wave
          frame.child.pixbuf = Gdk::Pixbuf.new(wave).adjust(@tw,@th)
          frame.modify_bg(Gtk::STATE_NORMAL,BLACK)
          frame.modify_bg(Gtk::STATE_NORMAL,GREEN) if @keep.include? self[n]
          frame.modify_bg(Gtk::STATE_NORMAL,RED) if @delete.include? self[n]
          frame.modify_bg(Gtk::STATE_NORMAL,BLUE) if @move.include? self[n]
          frame.modify_bg(Gtk::STATE_NORMAL,WHITE) if self[@current].similarity(self[n]) > 0.85
          frame.modify_bg(Gtk::STATE_NORMAL,YELLOW) if n == @current 
        else
          frame.child.pixbuf = nil
        end
        n += 1
      end
    end
  end
end
