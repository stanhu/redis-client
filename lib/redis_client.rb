# frozen_string_literal: true

require "socket"
require "redis_client/version"
require "redis_client/buffered_io"

class RedisClient
  Error = Class.new(StandardError)
  TimeoutError = Class.new(Error)
  ReadTimeoutError = Class.new(TimeoutError)
  WriteTimeoutError = Class.new(TimeoutError)

  def initialize
    @host = "localhost"
    @port = 6379
    @raw_connection = nil
  end

  def call(*command)
    raw_connection.write(RESP3.dump(command))
    RESP3.load(raw_connection)
  end

  def close
    @raw_connection&.close
    @raw_connection = nil
    self
  end

  def pipelined
    commands = []
    yield Pipeline.new(commands)
    call_pipelined(commands)
  end

  def call_pipelined(commands)
    raw_connection.write(RESP3.dump_all(commands))
    commands.map { RESP3.load(raw_connection) }
  end

  class Pipeline
    def initialize(commands)
      @commands = commands
    end

    def call(*command)
      @commands << command
      nil
    end
  end

  private

  def raw_connection
    @raw_connection ||= BufferedIO.new(TCPSocket.new(@host, @port))
  end
end

require "redis_client/resp3"