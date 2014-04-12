#!/bin/env ruby
require_relative 'sample.rb'

class Converter

  def initialize dir, vamp
    @dir = dir
    @name = File.basename(@dir)
    @samples = Dir[File.join(@dir,"*.wav")].collect{|f| Sample.new f}
    @simfile = File.join "/tmp/ot", @name, "sim", "sim.csv"
    @vamp = vamp
  end

  def split_bars
    delete = []
    @samples.each do |s|
      unless s.nr_slices == 16
        new = s.split_bars
        delete << s
        @samples += new
      end
    end
    @samples -= delete
  end

  def ensure_equal_size
    puts "checking samples in #{@dir}"
    abort "unequal sample sizes #{sizes.inspect}" unless @samples.collect{|s| s.nr_samples}.uniq.size == 1
  end

  def normalize
    puts "normalizing samples in #{@dir}"
    @samples.each{|s| s.normalize}
  end

  def similarity
    puts "calculating similarity matrix"
    @similarities = []
    @samples.each_with_index do |s1,i|
      @similarities << []
      @samples[0..i].each_with_index do |s2,j|
        sim = s1.similarity s2, @vamp
        @similarities[i][j] = sim.to_f
        @similarities[j][i] = sim.to_f
      end
    end
  end

  def select criterea # min or max
    nr = case @samples.size
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
         else exit("cannot process #{@sample.size} samples")
         end
    puts "selecting #{nr} from #{@samples.size} samples"
    sim = @similarities.collect{|s| s.send(criterea)}
    (@samples.size - nr).times do
      i = sim.index sim.send(criterea)
      @samples.delete_at i
      sim.delete_at i
    end
    similarity
  end

  def sort
    CSV.open(@simfile,"w+") do |csv| 
      @similarities.each{|row| csv << row}
    end
    puts "sorting samples"
    idx = `./seriation.R #{@simfile}`.split(/\s+/).collect{|i| i.to_i-1}
    @samples = idx.collect{|i| @samples[i]}
  end

  def chain
    chain_dir = File.join @dir, "chain"
    FileUtils.mkdir_p chain_dir
    chain = File.join chain_dir, "#{@name}_#{@samples.size}.wav"
    puts "rendering #{chain}"
    `sox #{@samples.collect{|s| s.norm}.join ' '} #{chain}`
  end

  def slice
    puts "slicing samples"
    @samples.each{|s| s.slice}
  end

  def silence dur
    file = File.join "/tmp/ot", @name, "silence.wav"
    `sox -n -r 44100 -b 24 -c 2 #{file} trim 0 #{dur}` unless File.exists? file # wrong number of samples with sample durations
    file
  end

  def matrix
    slice
    matrix_dir = File.join @dir, "matrix"
    FileUtils.mkdir_p matrix_dir
    nr_slices = @samples.collect{|s| s.slices.size}.max
    slice_length = @samples.first.nr_samples/@samples.first.nr_slices/44100.0
    files = []
    16.times do |i|
      slices = @samples.collect{|s| s.slices[i]}
      puts slices.size
      until [2,4,8,12,16,24,32,48,64].include? slices.size 
        slices << silence(slice_length) # pad with silence
      end
      puts slices.size
      matrix = File.join matrix_dir, "#{"%03d" % (i+1).to_s}_#{@name}_#{slices.size}.wav"
      puts "rendering #{matrix}"
      `sox #{slices.join ' '} #{matrix}`
      files << matrix
    end
    File.open(File.join(matrix_dir,"matrix.txt"),"w+"){|f| f.puts @samples.collect{|s| s.name}.join("\n")}
    files
  end

end
