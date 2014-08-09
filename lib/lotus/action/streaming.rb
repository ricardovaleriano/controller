require 'json'

module Lotus
  module Action
    # Allows a user to send a stream of data for clients accessing a
    # Lotus::Action.
    #
    # By default the stream will be sent using the Server Sent Events
    # specification (https://developer.mozilla.org/en-US/docs/Server-sent_events/Using_server-sent_events).
    #
    # @example
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
    #       stream will_block: true do |out|
    #         out.write "streaming from lotus!"
    #         directories = [ File.join(File.expand_path("../", __FILE__)) ]
    #         fsevent = FSEvent.new
    #         out.write "you can push messages at any time..."
    #         counter = 1
    #         fsevent.watch(directories) { |dirs|
    #           counter += 1;
    #           out.write({dirs: dirs }, event: "refresh")
    #           out.close if counter == 10
    #         }
    #         fsevent.run
    #       end
    #     end
    #   end
    module Streaming
      # Transforms objects passed as argument to #write in a stream, into valid
      # Server Sent Event messages.
      #
      # This can (and should) be used as a example of implementation for any
      # other transports that we need. The public interface for a transport to
      # be usable by the Lotus::Action::Streaming api is: #open, #close and
      # #call.
      #
      # The #call will be invoked with the message and options passed by the
      # user.
      #
      # @example
      #   class StreamAction
      #     include Lotus::Action
      #     include Lotus::Action::Streaming
      #
      #     def call(params)
      #       stream do |out|
      #         out.write 'such a framework', event: 'starting'
      #       end
      #     end
      #   end
      #
      # The above example will generate an invocation to #call on the transport
      # with the same 2 parameters passed by the user: 'such a framework' and
      # the hash {event: 'starting'}. Each transport should treat the options
      # parameter as it's needs.
      #
      # The methods #open and #close receive a #write object, which is expected
      # to be the same stream available to the user inside the block passed to
      # #stream in a Lotus::Action. This is util for transports that need to
      # send some message to the cliente informing that the stream will start,
      # the same deal to those which need inform about the finshing of a
      # streaming.
      class SSE
        # The HTTP content type associated with this transport type.
        #
        # @return [String] the HTTP content type for this transport type
        def self.content_type; 'text/event-stream' end

        # The name for the HTTP content type to be used when configuring the
        # Lotus::Controller.
        # @example
        #   format SSE.format => SSE.content_type
        #
        # @return [Symbol] the identification for the sse content type
        def self.format; :sse; end

        # The method to be called as soon as the action is ready to begin the
        # streaming to the client.
        #
        # SSE doesn't need to send any messages alerting that a streaming will
        # begin, so this method is here just for the sake of the interface.
        #
        # @param stream [#write]
        def open(stream); nil end

        # Transforms an object into a valid sse message by appending the
        # 'data:' string to it. It the first parameter isn't a String, it will
        # try to transform the Object into a JSON representation.
        #
        # The unique keys that will be searched in the options parameter are
        # :id and :event. The values for those keys, when they exist, will be
        # used to form the sse message as well.
        #
        # @example
        #   see.call('much streaming', event: 'open_connection') # => event: 'open_connection'\ndata: much_streaming\n\n
        #
        # @param message [<String, Object>] the message to be sent via sse
        # @param options [Hash] optional :id and :event for the sse message
        # @return [String] the valid sse string message
        def call(message, options = {})
          event, id = options.fetch(:event, nil), options.fetch(:id, nil)
          message = JSON.generate(message) unless message.is_a? String
          construct_message message, id, event
        end

        # Will be called when the user decides to finish the streaming. Since
        # sse doesn't need to inform the client that the streaming is finishing,
        # just writes nil into the stream so Lotus::Action::Streaming knows that
        # it needs close the connection.
        #
        # @param stream [#write] the client stream
        def close(stream)
          stream.write nil
        end

        private

        # Creates a string well formated to be recognized as a valid sse message
        #
        # @param message [String] the text to be sent as data: value
        # @param id [String] the id for this sse message
        # @param event [String] an event name for this sse message
        # @retur [String] the valid sse message
        def construct_message(message, id, event)
          final_message = ""
          final_message << "id: #{id}\n" if id
          final_message << "event: #{event}\n" if event
          final_message << "data: #{message}\n\n"
        end
      end

      # All transports implemented by the Lotus::Action::Streaming
      KNOWN_TRANSPORTS = [ SSE ]

      Lotus::Controller.configure do |config|
        KNOWN_TRANSPORTS.each do |transport_type|
          format transport_type.format => transport_type.content_type
        end
      end

      class Stream
        def initialize(transport, blocking_code)
          @transport, @blocking_code = transport, blocking_code
          @queue = Queue.new
        end

        def open(env)
          @transport.open self
          Thread.new { @blocking_code.call self }.abort_on_exception = true
          self
        end

        def write(message, options = {})
          @queue.push(
            message ? ->(){ @transport.call message, options } : nil
          )
        end

        def each(&async_blk)
          loop {
            message = @queue.pop
            if message
              yield message.call
            else
              break
            end
          }
        end

        def close
          @transport.close self
        end
      end

      begin
        require 'eventmachine'
      rescue LoadError
      end
      class EventStream
        include ::EM::Deferrable if defined? ::EM::Deferrable

        def initialize(transport, async_code, scheduler = :next_tick)
          @transport, @async_code = transport, async_code
          @scheduler = scheduler
        end

        def open(env)
          @transport.open self
          response = [ 200, { 'Content-Type' => @transport.class.content_type }, self ]
          env['async.callback'].call response
          EM::send(@scheduler) { @async_code.call self }
          throw :async
        end

        def write(message, options = {})
          EM::next_tick {
            if message
              @async_blk.call(
                @transport.call message, options
              )
            else
              succeed
            end
          }
        end

        def each(&async_blk)
          @async_blk = async_blk
        end

        def close
          @transport.close self
        end
      end

      protected

      def stream(options = {}, &blk)
        transport = prepare_for_transport options.fetch(:transport, SSE)
        will_block = options.fetch(:will_block, false)
        stream = new_stream will_block, transport, blk
        self.body = stream.open @_env
      end

      private

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
