require "rack"
require "rb-fsevent"

class Streammer
  def initialize(env)
  end

  def each(&blk)
      directories = [
        File.join(File.expand_path("../", __FILE__)),
      ]
      fsevent = FSEvent.new
      q = Queue.new

      puts "new connection..."
      fsevent.watch(directories) { |dirs|
        puts "go go go!"
        p blk
        q.push "{dirs: '#{dirs}', event: 'refresh'}\n"
        puts "blah!"
      }

      Thread.new {
        fsevent.run
      }

      while chunck = q.pop
        yield chunck
      end

    #  # Watch the above directories
    #  fsevent.watch(directories) do |dirs|
    #    puts "go go go!"
    #    p dirs
    #    # Send a message on the "refresh" channel on every update
    #    EventMachine.schedule { yield "{dirs: '#{dirs}', event: 'refresh'}" }
    #  end

    #EventMachine.defer do
    #  puts "deferred..."
    #  fsevent.run
    #end# deferred
  end
end

run ->(env) { [200, {"Content-Type" => "text/event-stream"}, Streammer.new(env)] }
