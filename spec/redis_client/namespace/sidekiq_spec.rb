# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Sidekiq Integration with RedisClient::Namespace" do
  let(:redis_url) { "redis://localhost:#{redis_port}/15" } # Use test DB 15
  let(:namespace) { "sidekiq_test" }
  let(:redis_port) { ENV.fetch("REDIS_PORT", 6379) }

  around do |example|
    # Skip if Sidekiq is not available
    begin
      require "sidekiq"
      require "sidekiq/testing"
    rescue LoadError
      skip "Sidekiq is not installed"
    end

    # Use real Redis mode
    Sidekiq::Testing.disable! do
      example.run
    end
  end

  before do
    # Configure Sidekiq with namespace middleware
    Sidekiq.configure_client do |config|
      config.redis = {
        url: redis_url,
        middlewares: [RedisClient::Namespace::Middleware],
        custom: { namespace: namespace, separator: ":" }
      }
    end

    Sidekiq.configure_server do |config|
      config.redis = {
        url: redis_url,
        middlewares: [RedisClient::Namespace::Middleware],
        custom: { namespace: namespace, separator: ":" }
      }
    end
  end

  after do
    # Clean up test database
    raw_redis = RedisClient.config(url: redis_url).new_client
    raw_redis.call("FLUSHDB")
    raw_redis.close
  end

  describe "Basic Redis operations through Sidekiq.redis" do
    it "performs SET and GET operations with namespace" do
      Sidekiq.redis do |conn|
        # SET operation
        conn.set("mykey", "myvalue")

        # GET operation
        expect(conn.get("mykey")).to eq("myvalue")
      end

      # Verify the key is actually namespaced in Redis
      raw_redis = RedisClient.config(url: redis_url).new_client
      expect(raw_redis.call("GET", "#{namespace}:mykey")).to eq("myvalue")
      expect(raw_redis.call("GET", "mykey")).to be_nil
      raw_redis.close
    end

    it "performs LPUSH and BRPOP operations with namespace" do
      Sidekiq.redis do |conn|
        # LPUSH operation
        conn.lpush("myqueue", ["item1", "item2"])

        # Verify list length
        expect(conn.llen("myqueue")).to eq(2)
      end

      # Verify the list is actually namespaced in Redis
      raw_redis = RedisClient.config(url: redis_url).new_client
      expect(raw_redis.call("LLEN", "#{namespace}:myqueue")).to eq(2)
      expect(raw_redis.call("LLEN", "myqueue")).to eq(0)

      # BRPOP operation
      Sidekiq.redis do |conn|
        result = conn.brpop("myqueue", timeout: 1)
        expect(result).to eq(["myqueue", "item1"])
      end

      raw_redis.close
    end

    it "handles multiple keys in a single operation" do
      Sidekiq.redis do |conn|
        # MSET operation
        conn.mset("key1", "val1", "key2", "val2")

        # MGET operation
        expect(conn.mget("key1", "key2")).to eq(["val1", "val2"])
      end

      # Verify all keys are namespaced
      raw_redis = RedisClient.config(url: redis_url).new_client
      expect(raw_redis.call("GET", "#{namespace}:key1")).to eq("val1")
      expect(raw_redis.call("GET", "#{namespace}:key2")).to eq("val2")
      raw_redis.close
    end
  end

  describe "Sidekiq-specific operations" do
    # Define a test worker
    before do
      stub_const("TestWorker", Class.new do
        include Sidekiq::Worker

        def perform(msg)
          # Worker implementation
        end
      end)
    end

    it "enqueues jobs with namespaced queue keys" do
      # Enqueue a job
      TestWorker.perform_async("test message")

      # Check that Sidekiq's internal keys are namespaced
      raw_redis = RedisClient.config(url: redis_url).new_client
      keys = raw_redis.call("KEYS", "*")

      # All keys should have the namespace prefix
      expect(keys).to all(start_with("#{namespace}:"))

      # Sidekiq specific keys should exist
      expect(keys.join(",")).to match(/#{namespace}:queue/)

      raw_redis.close
    end

    it "allows Sidekiq to read its own namespaced data" do
      # Set up some test data
      Sidekiq.redis do |conn|
        conn.sadd("queues", "default")
        conn.lpush("queue:default", '{"class":"TestWorker","args":["test"]}')
      end

      # Verify Sidekiq can read the data
      Sidekiq.redis do |conn|
        expect(conn.smembers("queues")).to include("default")
        expect(conn.llen("queue:default")).to eq(1)
      end
    end
  end
end
