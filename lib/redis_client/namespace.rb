# frozen_string_literal: true

require "redis-client"
require_relative "namespace/version"
require_relative "namespace/command_builder"

class RedisClient
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