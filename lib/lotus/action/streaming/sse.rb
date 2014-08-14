module Lotus
  module Action
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
          event, id, retry_time =
            options.fetch(:event, nil),
            options.fetch(:id, nil),
            options.fetch(:retry, nil)
          message = JSON.generate(message) unless message.is_a? String
          construct_message message, id, event, retry_time
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
        def construct_message(message, id, event, retry_time)
          final_message = ""
          final_message << "retry: #{retry_time}\n" if retry_time
          final_message << "id: #{id}\n" if id
          final_message << "event: #{event}\n" if event
          message.split("\n").each do |chunck|
            final_message << "data: #{chunck}\n"
          end
          final_message << "\n"
        end
      end
    end
  end
end
