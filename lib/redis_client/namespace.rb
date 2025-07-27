# frozen_string_literal: true

require "redis-client"
require_relative "namespace/version"
require_relative "namespace/command_builder"

class RedisClient
  class Namespace
    include RedisClient::Namespace::CommandBuilder

    class Error < StandardError; end

    def initialize(namespace = "")
      @namespace = namespace
    end
  end
end