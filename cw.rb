#!/usr/bin/env ruby
## Reads text from stdin and pipes through a toolchain
## to play the corresponding CW.
require 'thread'
require 'tempfile'

options = {:u => '', :w => 35}
text_queue = []
mutex = Mutex.new
cv = ConditionVariable.new

NAME = File.basename(__FILE__)
def log(msg)
  puts "#{NAME}: #{msg}"
end

ebook2cw = `/usr/bin/which ebook2cw`.strip!
if not ebook2cw or not File.exists? ebook2cw then
  DIR = File.dirname(__FILE__)
  ebook2cw = DIR + "/ebook2cw"
  if not File.exists? ebook2cw then
    log "ERROR: ebook2cw not found!"
    exit
  end
end

# Returns a command string for IO.popen including the current options.
def current_command(ebook2cw, options)
  # IO.popen() needs shell-style quoting.
  cmd = '"' + ebook2cw + '"'
  options.each do |k, v|
    if v.size > 0 then
      cmd += %Q{ -#{k} "#{v}"}
    else
      cmd += %Q{ -#{k}}
    end
  end
  cmd
end

log 'launched'
continue = true
thread = Thread.start(text_queue) do |q|
  loop do
    text = nil
    mutex.synchronize do
      while continue and q.empty? do
        cv.wait(mutex)
      end
      text = q.shift
    end

    if not text.nil? then
      log "spawning cw process for: #{text}"
      Tempfile.open(NAME) do |file|
        options[:o] = file.path
        cmd = current_command(ebook2cw, options)
        IO.popen(cmd, 'w') do |cw|
          log "spawned pid #{cw.pid}"
          cw.write text
        end

        # ebook2cw tries to append 0000.mp3 but only has 79 chars available
        # it truncates the path at 78 chars, so >78 ends in a single 0
        chapter = file.path + "0000.mp3"
        chapter = chapter[0...79]
        if File.exists? chapter then
          puts "playing audio from #{chapter}"
          `afplay "#{chapter}"`
        else
          log %Q(*** Audio file "#{chapter}" not found!)
        end
        file.delete
      end
    elsif not continue then
      log 'cw generator thread exiting'
      Thread.current.exit
    end
  end
end

while text = gets do
  log "got line: #{text}"
  mutex.synchronize do
    text_queue << text
    cv.signal
  end
end

# stdin closed - time to leave
continue = false
mutex.synchronize { cv.signal }
thread.join
log "exiting"
0
