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
      cw = IO.popen('ebook2cw', 'w')
      log "spawned pid #{cw.pid}"
      cw.write text
      cw.close

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
