require "rack"
require "rb-fsevent"

class Streammer
  def each(&blk)
      directories = [
        File.join(File.expand_path("../", __FILE__)),
      ]
      fsevent = FSEvent.new
      q = Queue.new

      puts "new connection..."
      fsevent.watch(directories) { |dirs|
        q.push "{dirs: '#{dirs}', event: 'refresh'}\n"
      }

      Thread.new { fsevent.run }

      while chunck = q.pop
        yield chunck
      end
  end
end

run ->(env) { [200, {"Content-Type" => "text/event-stream"}, Streammer.new] }
