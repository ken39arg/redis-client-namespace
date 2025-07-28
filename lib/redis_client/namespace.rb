# frozen_string_literal: true

require "redis-client"
require_relative "namespace/version"
require_relative "namespace/command_builder"

class RedisClient
  # RedisClient::Namespace provides transparent key namespacing for redis-client.
  #
  # It works by intercepting Redis commands and prefixing keys with a namespace,
  # allowing multiple applications or components to share a single Redis instance
  # without key collisions.
  #
  # @example Basic usage
  #   builder = RedisClient::Namespace.new("myapp")
  #   client = RedisClient.new(command_builder: builder)
  #   client.call("SET", "key", "value")  # Actually sets "myapp:key"
  #
  # @example Custom separator
  #   builder = RedisClient::Namespace.new("myapp", separator: "-")
  #   client = RedisClient.new(command_builder: builder)
  #   client.call("SET", "key", "value")  # Actually sets "myapp-key"
  class Namespace
    include RedisClient::Namespace::CommandBuilder

    class Error < StandardError; end

    attr_reader :namespace, :separator, :parent_command_builder

    def initialize(namespace = "", separator: ":", parent_command_builder: RedisClient::CommandBuilder)
      @namespace = namespace
      @separator = separator
      @parent_command_builder = parent_command_builder
    end
  end
end
