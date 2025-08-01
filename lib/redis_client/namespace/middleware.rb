# frozen_string_literal: true

require_relative "command_builder"

class RedisClient
  class Namespace
    # Middleware for RedisClient to add namespace support
    #
    # This module implements the RedisClient middleware interface to intercept
    # Redis commands and apply namespace transformations. It automatically prefixes
    # keys with a namespace and removes the prefix from certain command results.
    #
    # @see https://github.com/redis-rb/redis-client/blob/master/README.md#instrumentation-and-middlewares
    #
    # @example Basic usage with RedisClient
    #   client = RedisClient.config(
    #     middlewares: [RedisClient::Namespace::Middleware],
    #     custom: { namespace: "myapp", separator: ":" }
    #   ).new_client
    #
    #   client.call("SET", "key", "value")  # Actually sets "myapp:key"
    #   client.call("GET", "key")           # Gets "myapp:key" and returns "value"
    #
    # The middleware requires the following custom configuration:
    # - namespace: The namespace prefix to apply (required)
    # - separator: The separator between namespace and key (optional, default: ":")
    module Middleware
      def call(command, redis_config)
        namespace = redis_config.custom[:namespace] or return super
        separator = redis_config.custom[:separator] || ":"
        command = CommandBuilder.namespaced_command(command, namespace: namespace, separator: separator)
        super.tap do |result|
          CommandBuilder.trimed_result(command, result, namespace: namespace, separator: separator)
        end
      end

      def call_pipelined(commands, redis_config)
        namespace = redis_config.custom[:namespace] or return super
        separator = redis_config.custom[:separator] || ":"
        commands = commands.map do |cmd|
          CommandBuilder.namespaced_command(cmd, namespace: namespace, separator: separator)
        end
        super.tap do |results|
          commands.each_with_index do |command, i|
            CommandBuilder.trimed_result(command, results[i], namespace: namespace, separator: separator)
          end
        end
      end
    end
  end
end
