#!/usr/bin/env ruby
## Reads text from stdin and pipes through a toolchain
## to play the corresponding CW.
require 'thread'

AUDIO_FILE = 'Chapter0000.mp3'

options = {}
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
# IO.popen() needs shell-style quoting.
ebook2cw = %Q("#{ebook2cw}")

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
      IO.popen(ebook2cw, 'w') do |cw|
        log "spawned pid #{cw.pid}"
        cw.write text
      end

      if File.exists? AUDIO_FILE then
        puts 'playing audio'
        `afplay #{AUDIO_FILE}`
        File.delete AUDIO_FILE
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
