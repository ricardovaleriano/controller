require 'json'
require 'lotus/action/streaming/sse'
require 'lotus/action/streaming/stream'

# the following should be replaced by a check in the em stuff. but i haven't
# figured out why it's not working. Need to be something like:
# require 'event_stream' if defined?(EM)
begin
  require 'eventmachine'
  require 'lotus/action/streaming/event_stream'
rescue LoadError
  # this app do not need event_stream
end

module Lotus
  module Action
    # Send a stream of data for clients accessing a Lotus::Action.
    #
    # By default the stream will be sent using the Server Sent Events
    # specification (https://developer.mozilla.org/en-US/docs/Server-sent_events/Using_server-sent_events).
    #
    # @example simple streaming (without blocking) by calling #straem
    #  require 'lotus/controller'
    #  require 'lotus/action/streaming'
    #  require 'listen'
    #
    #  class NonBlocking
    #    include Lotus::Action
    #    include Lotus::Action::Streaming
    #
    #    def call(params)
    #      stream do |out|
    #        directories = [ File.expand_path('../', __FILE__) ]
    #        listener = Listen.to(*directories) { |modified, added, moved|
    #          out.write({ dirs: modified }, event: 'refresh')
    #        }
    #        listener.start
    #      end
    #    end
    #  end
    #
    # The #stream method works for threaded and evented servers as well. But if
    # you will use this feature in an evented server, and the code in your
    # action is blocking, you will need to tell it explicitly. In this case, use
    # the method #blocking_stream. Or, better yet, find an non blocking
    # alternative for your implementation.
    #
    # @example blocking streaming by calling blocking_stream
    #   require 'lotus/controller'
    #   require 'lotus/action/streaming'
    #
    #   class Blocking
    #     require 'rb-fsevent'
    #
    #     include Lotus::Action
    #     include Lotus::Action::Streaming
    #
    #     def self.call(env)
    #       new.call(env)
    #     end
    #
    #     def call(params)
    #       blocking_stream do |out|
    #         directories = [ File.join(File.expand_path("../", __FILE__)) ]
    #         fsevent = FSEvent.new
    #         fsevent.watch(directories) { |dirs|
    #           out.write({dirs: dirs }, event: "refresh")
    #         }
    #         fsevent.run
    #       end
    #     end
    #   end
    module Streaming
      # All transports implemented by the Lotus::Action::Streaming
      KNOWN_TRANSPORTS = [ SSE ]

      Lotus::Controller.configure do |config|
        KNOWN_TRANSPORTS.each do |transport_type|
          format transport_type.format => transport_type.content_type
        end
      end

      protected

      def stream(transport_type = SSE, &blk)
        open_stream false, transport_type, blk
      end

      def blocking_stream(transport_type = SSE, &blk)
        open_stream true, transport_type, blk
      end

      private

      def open_stream(blocking, transport_type, blk)
        transport = prepare_for_transport transport_type
        stream = new_stream blocking, transport, blk
        self.body = stream.open @_env
      end

      def prepare_for_transport(transport_type)
        transport = transport_type.new
        raise 'noooo... invalid transport' unless transport.respond_to? :call

        self.headers['Cache-Control'] = 'no-cache'
        self.headers['Content-Type']  = transport_type.content_type
        self.format = transport_type.format
        transport
      end

      def new_stream(will_block, transport, blk)
        if @_env['async.callback']
          scheduler = will_block ? :defer : :next_tick
          EventStream.new transport, blk, scheduler
        else
          Stream.new transport, blk
        end
      end
    end
  end
end
