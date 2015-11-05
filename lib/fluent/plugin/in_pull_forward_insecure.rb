module Fluent
  class PullForwardInput < Input
    DEFAULT_PULLFORWARD_LISTEN_PORT = 24280

    Fluent::Plugin.register_input('pull_forward_insecure', self)

    config_param :fetch_interval, :time, :default => 600 # 10m
    config_param :timeout, :time, :default => 60

    config_section :server, param_name: :servers do
      config_param :host, :string
      config_param :port, :integer, :default => DEFAULT_PULLFORWARD_LISTEN_PORT
    end

    attr_reader :hostname_resolver

    def initialize
      super
      require 'resolve/hostname'
      require 'net/http'
      require 'yajl'
    end

    # Define `log` method for v0.10.42 or earlier
    unless method_defined?(:log)
      define_method("log") { $log }
    end

    def configure(conf)
      super
      @resolver = Resolve::Hostname.new(:system_resolver => true)
    end

    def start
      super
      @running = true
      @thread = Thread.new(&method(:fetcher))
    end

    def shutdown
      super
      @running = false
      @thread.join
    end

    def fetcher
      next_fetch = Time.now
      while @running
        if Time.now >= next_fetch
          @servers.each do |server|
            if @running
              fetch(server)
            end
          end
          next_fetch = Time.now + @fetch_interval
        end
        break unless @running
        sleep 1
      end
    end

    def fetch(server)
      body = nil

      begin
        address = @resolver.getaddress(server.host)
        http = Net::HTTP.new(address, server.port)
        http.open_timeout = @timeout
        http.read_timeout = @timeout

        req = Net::HTTP::Get.new('/')

        res = http.start{ http.request(req) }
        if res && res.is_a?(Net::HTTPSuccess)
          body = res.body
        else
          log.warn "failed to GET from Fluentd PullForward: #{server.host}, #{address}:#{server.port}, by #{res.class}"
        end
      rescue IOError, EOFError, SystemCallError => e
        log.warn "net/http GET raised an exception: #{e.class}, '#{e.message}'"
      end
      return unless body

      data = nil
      begin
        data = Yajl::Parser.parse(body)
      rescue => e
        # maybe parse error
        log.warn "an error occured for parse of transferred content: #{e.class}, '#{e.message}'"
      end
      return unless data

      bundle = {}
      data.each do |tag, time, record|
        bundle[tag] ||= Fluent::MultiEventStream.new
        bundle[tag].add(time, record)
      end
      bundle.each do |tag, es|
        Fluent::Engine.emit_stream(tag, es)
      end
    end
  end
end
