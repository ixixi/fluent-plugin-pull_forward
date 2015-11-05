require 'fluent/mixin/config_placeholders'
require 'webrick'
require 'webrick/https'

require_relative 'webrick_logger_bridge'

module Fluent
  class PullForwardOutput < BufferedOutput
    DEFAULT_PULLFORWARD_LISTEN_PORT = 24280

    Fluent::Plugin.register_output('pull_forward_insecure', self)

    config_param :self_hostname, :string
    include Fluent::Mixin::ConfigPlaceholders

    config_param :bind, :string, :default => '0.0.0.0'
    config_param :port, :integer, :default => DEFAULT_PULLFORWARD_LISTEN_PORT

    config_param :server_loglevel, :string, :default => 'WARN'

    config_set_default :buffer_type, 'pullpool'
    config_set_default :flush_interval, 3600 # 1h

    # REQUIRED: buffer_path

    # same with TimeSlicedOutput + FileBuffer
    # 16MB * 256 -> 4096MB
    config_set_default :buffer_chunk_limit, 1024 * 1024 * 16 # 16MB
    config_set_default :buffer_queue_limit, 256

    def initializer
      super
    end

    unless method_defined?(:log)
      define_method("log") { $log }
    end

    def configure(conf)
      super
    end

    def start
      super
      @thread = Thread.new(&method(:run))
    end

    def shutdown
      @server.stop if @server
      @thread.kill
      @thread.join
    end

    def run
      realm = "Fluentd fluent-plugin-pullforward server"

      logger = $log
      server_logger = Fluent::PluginLogger.new(logger)
      server_logger.level = @server_loglevel


      @server = WEBrick::HTTPServer.new(
        :BindAddress => @bind,
        :Port => @port,
        # :DocumentRoot => '.',
        :Logger => Fluent::PullForward::WEBrickLogger.new(server_logger),
        :AccessLog => [],
      )
      @server.logger.info("hogepos")

      @server.mount_proc('/') do |req, res|
        if req.path != '/'
          raise WEBrick::HTTPStatus::NotFound, "valid path is only '/'"
        end
        res.content_type = 'application/json'
        res.body = dequeue_chunks()
      end

      log.info "listening pullforward socket on #{@bind}:#{@port}"
      @server.start
    end

    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    def dequeue_chunks
      response = []

      unpacker = MessagePack::Unpacker.new

      @buffer.pull_chunks do |chunk|
        next if chunk.empty?
        unpacker.feed_each(chunk.read) do |ary|
          response << ary
        end
      end

      response.to_json
    end
  end
end
