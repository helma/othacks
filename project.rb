#!/bin/env ruby
require 'fileutils'
require 'pathname'
require 'yaml'
require_relative "sample.rb"

class Project

  attr_accessor :data
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
    FileUtils.mv @file, bak
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
    Pathname.new(path).relative_path_from(Pathname.new(@dir)).to_s
  end

  def remove_samples path
    pattern = rel_path path
    @samples -= @samples.select{|s| s["PATH"] and s["PATH"].match(Regexp.new(Regexp.escape(pattern)))}
  end

  def slot_nrs type
    slots(type).collect{|s| s["SLOT"].to_i}.sort
  end

  def free_slots type
    (1..slot_nrs(type).last).to_a - slot_nrs(type)
  end

  def next_slot type
    slot_nrs(type).last.to_i + 1
  end

  def first_free_slot type
    free_slots(type).empty? ? s=next_slot(type) : s=free_slots(type).first
    "%03d" % s
  end

  def add_matrix files
    n = next_slot "FLEX"
    files.each do |f|
      @samples << {
        "TYPE" => "FLEX",
        "SLOT" => "%03d" % n,
        "PATH" => rel_path(f),
        "BPMx24" => (24*Sample.new(f).bpm).to_i,
        "TSMODE" => "2",
        "LOOPMODE" => "0",
        "GAIN" => "48",
        "TRIGQUANTIZATION" => "1"
      }
      n+=1
    end
  end

  def add_chain file
    nr = first_free_slot("STATIC")
    @samples << {
      "TYPE" => "STATIC",
      "SLOT" => nr,
      "PATH" => rel_path(file),
      "BPMx24" => (24*Sample.new(file).bpm).to_i,
      "TSMODE" => "0",
      "LOOPMODE" => "0",
      "GAIN" => "48",
      "TRIGQUANTIZATION" => "1"
    }
  end

end
