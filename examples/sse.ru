$: << File.expand_path("../../lib", __FILE__)

require 'lotus/controller'
require 'lotus/action/streaming'
require 'rb-fsevent'

class SSEAction
  include Lotus::Action
  include Lotus::Action::Streaming

  def self.call(env)
    new.call(env)
  end

  def call(params)
    stream do |out|
      out.write "streaming from lotus!"

      directories = [ File.join(File.expand_path("../", __FILE__)) ]
      fsevent = FSEvent.new

      out.write "you can push messages at any time..."

      fsevent.watch(directories) { |dirs|
        out.write({ dirs: dirs }, event: "refresh")
      }

      fsevent.run
    end
  end
end

map("/") { run Rack::Directory.new(File.expand_path("../", __FILE__)) }
map("/live") { run SSEAction }
