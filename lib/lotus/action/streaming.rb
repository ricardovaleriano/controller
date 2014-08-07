require 'json'

module Lotus
  module Action
    module Streaming
      Lotus::Controller.configure do |config|
        format sse: 'text/event-stream'
      end

      class SSE
        def content_type; 'text/event-stream' end
        def format; :sse end

        def call(message, options)
          # transform the message here
        end

        def close
          nil
        end
      end

      protected

      def stream(transport = SSE.new, &blk)
        raise 'invalid transport' unless transport.respond_to? :call

        self.headers['Cache-Control'] = 'no-cache'
        self.headers['Content-Type']  = transport.content_type

        self.format = transport.format
        if @_env['async.callback']
          evented_stream transport
        else
          threaded_stream transport
        end
      end

      private

      def evented_stream(transport)
        response = [ 200, { 'Content-Type' => transport.content_type }, [] ]
        @_env['async.callback'].call response
        throw :async
      end

      def threaded_stream(transport)
      end
    end
  end
end
