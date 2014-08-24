require 'lotus/router'
require 'lotus/controller'
require 'lotus/action/streaming'
require 'redis'
require 'em-hiredis'

class RedisChatRouterController
  include Lotus::Controller

  action 'Subscribe' do
    include Lotus::Action::Streaming

    def call(params)
      blocking_stream do |out|
        Redis.new.subscribe('messages') do |on|
          on.subscribe do |channel, subscriptions|
            out.write("Subscribed to ##{channel} (#{subscriptions} subscriptions)")
          end

          on.message do |_, data|
            out.write(data, event: "message_created")
          end
        end
      end
    end
  end

  action 'Publish' do
    def call(params)
      RedisChatController.publisher.publish 'messages', params[:message]
    end
  end

  action 'EMSubscribe' do
    include Lotus::Action::Streaming

    def call(params)
      stream do |out|
        pubsub = EM::Hiredis.connect.pubsub
        pubsub.subscribe('messages')
        pubsub.on(:subscribe) do |channel, subscriptions|
          out.write("new subscriber on ##{channel}")
        end
        pubsub.on(:message) do |_, data|
          out.write(data, event: 'message_created')
        end

        puts 'one more connected!'
      end
    end
  end

  action 'EMPublish' do
    def call(params)
      EM::Hiredis.connect.publish 'messages', params[:message]
    end
  end
end

router = Lotus::Router.new do
  get '/router/em/sub', to: RedisChatRouterController::EMSubscribe
  get '/router/em/pub', to: RedisChatRouterController::EMPublish
end

run router
