#!/bin/env ruby
require 'fileutils'
require 'pathname'
require 'yaml'

class Project

  attr_accessor :samples
  def initialize dir

    @meta = {}
    @settings = {}
    @states = {}
    @samples = []
    @dir = dir
    @file = File.join(dir,"project.work")

    section = nil
    File.open(@file).each_line do |line|
      line.chomp!
      if line.match(/^\[/) 
        if line.match(/^\[\//) 
          section = nil
        else
          section = line.gsub(/[\[\]]/,'')
          @samples << {} if section == "SAMPLE"
        end
      elsif line.match(/=/)
        key, value = line.split "="
        case section
        when "META"
          @meta[key] = value
        when "SETTINGS"
          @settings[key] = value
        when "STATES"
          @states[key] = value
        when "SAMPLE"
          @samples.last[key] = value
        end
      end
    end
    remove_empty_samples
  end

  def to_s
    s=''
    ["META","SETTINGS","STATES"].each do |section|
      s+="[#{section}]\r\n"
      instance_variable_get("@#{section.downcase}").each{ |k,v| s+="#{k}=#{v}\r\n" }
      s+="[/#{section}]\r\n\r\n"
    end
    sort!
    @samples.each do |sample|
      s+="[SAMPLE]\r\n"
      sample.each { |k,v| s+="#{k}=#{v}\r\n" }
      s+="[/SAMPLE]\r\n\r\n"
    end
    s
  end

  def save
    bak = File.join @dir, "bak"
    FileUtils.mkdir_p bak
    bakfile = File.join(bak,"project.#{Time.now.strftime("%Y%m%d-%H%M%S")}")
    FileUtils.mv @file, bakfile
    File.open(@file,"w+"){|f| f.puts self.to_s}
  end

  def sort!
    @samples.sort_by!{|s| s["TYPE"]+s["SLOT"]}
  end

  def slots type
    @samples.select{|s| s["TYPE"] == type}.sort_by{|s| s["SLOT"]}
  end

  def empty_samples
    @samples.select{|s| s["PATH"].nil?}
  end

  def remove_empty_samples
    @samples -= empty_samples
  end

  def rel_path path
    Pathname.new(File.expand_path(path)).relative_path_from(Pathname.new(File.expand_path(@dir))).to_s
  end

=begin
  def remove_samples paths
    paths.each do |path|
      pattern = rel_path path
      @samples -= @samples.select{|s| s["PATH"] == pattern}
    end
  end
=end

  def slot_nrs type
    slots(type).collect{|s| s["SLOT"].to_i}.sort
  end

  def free_slots type
    slot_nrs(type).empty? ? [] : (1..slot_nrs(type).last).to_a - slot_nrs(type)
  end

  def next_slot type
    slot_nrs(type).last.to_i + 1
  end

  def first_free_slot type
    free_slots(type).empty? ? next_slot(type) : free_slots(type).first
  end

  def add_matrix dir
    files = Dir[File.join(dir,"*.wav")].sort
    n = first_free_slot("STATIC")
    files.each do |f|
      bpm = @dir.split('/').grep(/\d\d\d/).first.to_i
      @samples << {
        "TYPE" => "STATIC",
        "SLOT" => "%03d" % n,
        "PATH" => rel_path(f),
        "BPMx24" => (24*bpm).round,
        "TSMODE" => "2",
        "LOOPMODE" => "0",
        "GAIN" => "48",
        "TRIGQUANTIZATION" => "1"
      }
      n+=1
    end
  end

  def add_chain file
    n = first_free_slot("STATIC")
    slot = {
      "TYPE" => "STATIC",
      "SLOT" => "%03d" % n,
      "PATH" => rel_path(file),
      "TRIM_BARSx100" => nil,
      "BPMx24" => nil,
      "TSMODE" => "2",
      "LOOPMODE" => "0",
      "GAIN" => "48",
      "TRIGQUANTIZATION" => "1"
    }
    if @dir.match(%r{/\d\d\d})
      bpm = @dir.split('/').grep(/\d\d\d/).first.to_i
      slot["BPMx24"] = 24*bpm
      slot.delete("TRIM_BARSx100")
    else
      length = File.basename(file,".wav").split(/_/).last.to_i
      slot["TRIM_BARSx100"] = (100*length/4.0).round
      slot.delete("BPMx24")
    end
    @samples << slot
  end

end

