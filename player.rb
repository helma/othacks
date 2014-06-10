#!/usr/bin/env ruby

class Player

  def initialize sample, loop=nil
    `mkfifo /tmp/mplayer`
    loop ? loop = "-loop 0" : loop = ""
    pid = spawn "mplayer -idle -slave #{loop} -input file=/tmp/mplayer '#{sample.path}'"
    Process.detach pid
  end

  def play sample
    `echo "loadfile '#{sample.path}'" > /tmp/mplayer`
    `echo "run" > /tmp/mplayer`
  end

  def pause
    `echo "pause" > /tmp/mplayer`
  end

  def quit
    `echo "quit" > /tmp/mplayer`
  end

end
