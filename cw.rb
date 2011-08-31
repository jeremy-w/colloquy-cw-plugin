#!/usr/bin/env ruby
## Reads text from stdin and pipes through a toolchain
## to play the corresponding CW.
require 'thread'

options = {}
text_queue = []
mutex = Mutex.new

continue = true
thread = Thread.start(text_queue) do |q|
  loop do
    mutex.lock
    text = q.shift
    mutex.unlock

    if not text.nil? then
      puts 'spawning cw process'
      cw = IO.popen('ebook2cw', 'w')
      puts 'spawned pid #{cw.pid}'
      cw.write text
      cw.close

      puts 'playing audio'
      `afplay Chapter0000.mp3`
      `rm Chapter0000.mp3`
    elsif not continue then
      puts 'cw generator thread exiting'
      Thread.current.exit 0
    end
  end
end

while text = gets do
  mutex.synchronize do
    text_queue << text
  end
end

# stdin closed - time to leave
continue = false
thread.join
puts 'cw generator exiting now'
0
