# frozen_string_literal: true

require "redis-client"
require_relative "namespace/version"
require_relative "namespace/command_builder"
require_relative "namespace/middleware"

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

    # Creates a command builder that conditionally applies namespacing.
    #
    # If the namespace is nil or empty, returns the parent_command_builder directly,
    # effectively disabling namespacing. Otherwise, creates a new Namespace instance.
    #
    # This is particularly useful for environment-based configuration where you want
    # to enable/disable namespacing based on environment variables.
    #
    # @param namespace [String, nil] The namespace to use. If nil or empty, namespacing is disabled
    # @param separator [String] The separator between namespace and key (default: ":")
    # @param parent_command_builder [Object] The parent command builder to use (default: RedisClient::CommandBuilder)
    # @return [Object] Either a Namespace instance or the parent_command_builder
    #
    # @example Environment-based namespacing
    #   # Enable namespacing only when REDIS_NAMESPACE is set
    #   builder = RedisClient::Namespace.command_builder(ENV.fetch("REDIS_NAMESPACE", ""))
    #   client = RedisClient.new(command_builder: builder)
    #
    #   # With REDIS_NAMESPACE=myapp: keys will be prefixed with "myapp:"
    #   # With REDIS_NAMESPACE="" or unset: no namespacing applied
    #
    # @example Sidekiq configuration
    #   Sidekiq.configure_server do |config|
    #     config.redis = {
    #       url: 'redis://localhost:6379/1',
    #       command_builder: RedisClient::Namespace.command_builder(ENV.fetch("REDIS_NAMESPACE", ""))
    #     }
    #   end
    def self.command_builder(namespace = "", separator: ":", parent_command_builder: RedisClient::CommandBuilder)
      if namespace.nil? || namespace.empty?
        parent_command_builder
      else
        new(namespace, separator: separator,
                       parent_command_builder: parent_command_builder)
      end
    end
  end
end
