module Dashing
  class EventsController < ApplicationController
    include ActionController::Live
    before_action :init_connection

    def index
      response.headers['Content-Type']      = 'text/event-stream'
      response.headers['X-Accel-Buffering'] = 'no'
      response.stream.write latest_events
      
      begin        
        @redis.with do |redis_connection|
          redis_connection.psubscribe("#{Dashing.config.redis_namespace}.*") do |on|
            on.pmessage do |pattern, event, data|
              response.stream.write("data: #{data}\n\n")
            end
          end
        end
      rescue IOError, ActionController::Live::ClientDisconnected
        logger.info "[Dashing][#{Time.now.utc.to_s}] Stream closed"
      ensure
        #@redis.shutdown { |redis_connection| redis_connection.quit }
        response.stream.close
      end
    end

    private 
    
    def latest_events
      @redis.with do |redis_connection|
        events = redis_connection.hvals("#{Dashing.config.redis_namespace}.latest")
        events.map { |v| "data: #{v}\n\n" }.join
      end
    end

    def init_connection 
      @redis = Dashing.redis
    end

  end
end
