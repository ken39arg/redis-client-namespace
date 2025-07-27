# frozen_string_literal: true

require "redis-client"
require_relative "namespace/version"

module RedisClient
  module Namespace
    class Error < StandardError; end
    
    # ここにNamespaceCommandBuilderクラスの実装を配置してください
  end
end