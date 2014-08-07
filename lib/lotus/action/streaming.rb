require 'json'

module Lotus
  module Action
    module Streaming
      Lotus::Controller.configure do |config|
        format sse: 'text/event-stream'
      end

      class SSE
        def initialize(app)
          @app = app
        end

        def open
          @app.headers["Content-Type"] = "..."
        end

        def call(message, options)
          # transform the message here
        end

        def close
          nil
        end
      end

      protected
      def stream(transport = :sse, &blk)
        # decides which transport to use
        # can receive an object that respondo_to? :transform
        # the stream knows to call #transport before write a message
      end
    end
  end
end
