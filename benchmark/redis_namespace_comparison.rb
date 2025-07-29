#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "benchmark/ips"
require "redis"
require "redis-namespace"
require "redis-client-namespace"

# Setup Redis connections
REDIS_HOST = ENV.fetch("REDIS_HOST", "127.0.0.1")
REDIS_PORT = ENV.fetch("REDIS_PORT", "6379")
REDIS_DB = ENV.fetch("REDIS_DB", "0")

puts "Redis Namespace Benchmark: redis-namespace vs redis-client-namespace"
puts "=" * 70
puts "Testing with redis-rb (Redis.new)"
puts "Redis: #{REDIS_HOST}:#{REDIS_PORT}/#{REDIS_DB}"
puts "=" * 70

# Create Redis clients
plain_redis = Redis.new(host: REDIS_HOST, port: REDIS_PORT, db: REDIS_DB)

# redis-namespace (traditional approach)
redis_namespace = Redis::Namespace.new("bench_old", redis: plain_redis)

# redis-client-namespace (new approach)
namespace_builder = RedisClient::Namespace.new("bench_new")
redis_client_namespace = Redis.new(host: REDIS_HOST, port: REDIS_PORT, db: REDIS_DB, command_builder: namespace_builder)

# Clean up before benchmark
plain_redis.flushdb

# Warm up
redis_namespace.set("warmup", "value")
redis_client_namespace.set("warmup", "value")
redis_namespace.get("warmup")
redis_client_namespace.get("warmup")

puts "\n## Single Key Operations"
puts

Benchmark.ips do |x|
  x.report("redis-namespace SET") do
    redis_namespace.set("key", "value")
  end

  x.report("redis-client-namespace SET") do
    redis_client_namespace.set("key", "value")
  end

  x.compare!
end

Benchmark.ips do |x|
  x.report("redis-namespace GET") do
    redis_namespace.get("key")
  end

  x.report("redis-client-namespace GET") do
    redis_client_namespace.get("key")
  end

  x.compare!
end

puts "\n## Multiple Key Operations"
puts

# Prepare data for MGET
10.times { |i| redis_namespace.set("mkey#{i}", "value#{i}") }
10.times { |i| redis_client_namespace.set("mkey#{i}", "value#{i}") }

keys = (0...10).map { |i| "mkey#{i}" }

Benchmark.ips do |x|
  x.report("redis-namespace MGET") do
    redis_namespace.mget(*keys)
  end

  x.report("redis-client-namespace MGET") do
    redis_client_namespace.mget(*keys)
  end

  x.compare!
end

puts "\n## List Operations"
puts

Benchmark.ips do |x|
  x.report("redis-namespace LPUSH") do
    redis_namespace.lpush("list", %w[item1 item2])
  end

  x.report("redis-client-namespace LPUSH") do
    redis_client_namespace.lpush("list", %w[item1 item2])
  end

  x.compare!
end

Benchmark.ips do |x|
  x.report("redis-namespace LRANGE") do
    redis_namespace.lrange("list", 0, -1)
  end

  x.report("redis-client-namespace LRANGE") do
    redis_client_namespace.lrange("list", 0, -1)
  end

  x.compare!
end

puts "\n## Hash Operations"
puts

Benchmark.ips do |x|
  x.report("redis-namespace HSET") do
    redis_namespace.hset("hash", "field1", "value1", "field2", "value2")
  end

  x.report("redis-client-namespace HSET") do
    redis_client_namespace.hset("hash", "field1", "value1", "field2", "value2")
  end

  x.compare!
end

Benchmark.ips do |x|
  x.report("redis-namespace HGETALL") do
    redis_namespace.hgetall("hash")
  end

  x.report("redis-client-namespace HGETALL") do
    redis_client_namespace.hgetall("hash")
  end

  x.compare!
end

puts "\n## Set Operations"
puts

Benchmark.ips do |x|
  x.report("redis-namespace SADD") do
    redis_namespace.sadd("set", %w[member1 member2])
  end

  x.report("redis-client-namespace SADD") do
    redis_client_namespace.sadd("set", %w[member1 member2])
  end

  x.compare!
end

Benchmark.ips do |x|
  x.report("redis-namespace SMEMBERS") do
    redis_namespace.smembers("set")
  end

  x.report("redis-client-namespace SMEMBERS") do
    redis_client_namespace.smembers("set")
  end

  x.compare!
end

puts "\n## Pattern Matching"
puts

# Create some keys for pattern matching
10.times { |i| redis_namespace.set("user:#{i}", "value#{i}") }
10.times { |i| redis_client_namespace.set("user:#{i}", "value#{i}") }

Benchmark.ips do |x|
  x.report("redis-namespace KEYS") do
    redis_namespace.keys("user:*")
  end

  x.report("redis-client-namespace KEYS") do
    redis_client_namespace.keys("user:*")
  end

  x.compare!
end

puts "\n## Complex Operations"
puts

# Prepare sorted set data
redis_namespace.zadd("zset", [[1, "member1"], [2, "member2"], [3, "member3"]])
redis_client_namespace.zadd("zset", [[1, "member1"], [2, "member2"], [3, "member3"]])

Benchmark.ips do |x|
  x.report("redis-namespace ZRANGE") do
    redis_namespace.zrange("zset", 0, -1)
  end

  x.report("redis-client-namespace ZRANGE") do
    redis_client_namespace.zrange("zset", 0, -1)
  end

  x.compare!
end

# Transactions
puts "\n## Transactions"
puts

Benchmark.ips do |x|
  x.report("redis-namespace MULTI") do
    redis_namespace.multi do |r|
      r.set("tx_key1", "value1")
      r.set("tx_key2", "value2")
    end
  end

  x.report("redis-client-namespace MULTI") do
    redis_client_namespace.multi do |r|
      r.set("tx_key1", "value1")
      r.set("tx_key2", "value2")
    end
  end

  x.compare!
end

# Clean up
plain_redis.flushdb

puts "\n#{"=" * 70}"
puts "Benchmark completed!"
