# frozen_string_literal: true

require "redis-client"
require_relative "namespace/version"
require_relative "namespace/command_builder"
require_relative "namespace/middleware"

class RedisClient
  # RedisClient::Namespace provides transparent key namespacing for redis-client.
  #
  # **DEPRECATED**: Using this class as a command_builder is deprecated.
  # Please use RedisClient::Namespace::Middleware instead for full namespace support
  # including automatic removal of namespace prefixes from command results.
  #
  # The command_builder approach only transforms outgoing commands but cannot
  # process incoming results to remove namespace prefixes from keys returned by
  # commands like KEYS, SCAN, BLPOP, etc.
  #
  # @deprecated Use {RedisClient::Namespace::Middleware} instead
  # @example Recommended middleware approach
  #   client = RedisClient.config(
  #     middlewares: [RedisClient::Namespace::Middleware],
  #     custom: { namespace: "myapp", separator: ":" }
  #   ).new_client
  #   client.call("SET", "key", "value")  # Actually sets "myapp:key"
  #   client.call("KEYS", "*")            # Returns ["key"] instead of ["myapp:key"]
  #
  # @example Legacy command_builder usage (not recommended)
  #   builder = RedisClient::Namespace.new("myapp")
  #   client = RedisClient.new(command_builder: builder)
  #   client.call("SET", "key", "value")  # Actually sets "myapp:key"
  #   client.call("KEYS", "*")            # Returns ["myapp:key"] - namespace not removed
  class Namespace
    class Error < StandardError; end

    attr_reader :namespace, :separator, :parent_command_builder

    def initialize(namespace = "", separator: ":", parent_command_builder: RedisClient::CommandBuilder)
      @namespace = namespace
      @separator = separator
      @parent_command_builder = parent_command_builder
    end

    def generate(args, kwargs = nil)
      CommandBuilder.namespaced_command(@parent_command_builder.generate(args, kwargs), namespace: @namespace,
                                                                                        separator: @separator)
    end
  end
end
