# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Sidekiq Integration with RedisClient::Namespace" do
  # Skip if Sidekiq is not available
  begin
    require "sidekiq"
    require "sidekiq/testing"
    require "sidekiq/launcher"
    require "sidekiq/job_retry"
    require "sidekiq/api"
  rescue LoadError
    skip "Sidekiq is not installed"
  end

  let(:redis_url) { "redis://localhost:#{redis_port}/15" } # Use test DB 15
  let(:namespace) { "sidekiq_test" }
  let(:redis_port) { ENV.fetch("REDIS_PORT", 6379) }

  # Common Redis configuration
  let(:redis_config) do
    {
      url: redis_url,
      middlewares: [RedisClient::Namespace::Middleware],
      custom: { namespace: namespace, separator: ":" }
    }
  end

  around do |example|
    # Use real Redis mode
    Sidekiq::Testing.disable! do
      example.run
    end
  end

  before do
    # Configure Sidekiq with namespace middleware
    Sidekiq.configure_client { |config| config.redis = redis_config }
    Sidekiq.configure_server { |config| config.redis = redis_config }
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

  describe "Sidekiq Launcher integration" do
    let(:sidekiq_config) do
      config = Sidekiq::Config.new
      config.default_capsule.concurrency = 1
      config[:queues] = ["default", "other"]
      # Use shared redis_config
      config.redis = redis_config
      config
    end

    # Retryable worker for testing
    before do
      stub_const("RetryableWorker", Class.new do
        include Sidekiq::Job

        sidekiq_options retry: 3

        def perform(key)
          # Record attempt count in Redis
          count = Sidekiq.redis { |c| c.incr("test:attempts:#{key}") }.to_i

          raise "First attempt always fails" if count == 1

          # First attempt always fails

          # Subsequent attempts succeed
          Sidekiq.redis { |c| c.set("test:result:#{key}", "success") }
        end
      end)
    end

    it "processes jobs with retry using actual launcher", :slow do
      # Clean Redis before test
      Sidekiq.redis(&:flushdb)

      launcher = Sidekiq::Launcher.new(sidekiq_config)

      begin
        # Start the launcher
        launcher.run

        # Enqueue a job that will fail first time
        job_id = RetryableWorker.perform_async("test123")

        # Wait for initial processing (should fail)
        sleep 1

        # Verify first attempt was made
        attempts = Sidekiq.redis { |c| c.get("test:attempts:test123") }
        expect(attempts).to eq("1")

        # Check that job is in retry set
        retry_set = Sidekiq::RetrySet.new
        expect(retry_set.size).to eq(1)

        # Get the retried job and retry it immediately
        retried_job = retry_set.first
        expect(retried_job.jid).to eq(job_id)
        retried_job.retry

        # Wait for retry processing (should succeed)
        sleep 1

        # Verify success
        result = Sidekiq.redis { |c| c.get("test:result:test123") }
        expect(result).to eq("success")

        # Verify attempts count
        attempts = Sidekiq.redis { |c| c.get("test:attempts:test123") }
        expect(attempts).to eq("2")

        # Verify retry set is now empty
        expect(retry_set.size).to eq(0)

        # Verify all keys are namespaced
        raw_redis = RedisClient.config(url: redis_url).new_client
        all_keys = raw_redis.call("KEYS", "*")
        expect(all_keys).to all(start_with("#{namespace}:"))
        raw_redis.close
      ensure
        # Clean shutdown
        launcher.quiet
        launcher.stop
        Sidekiq.redis(&:flushdb)
      end
    end

    it "uses correct namespace for queues and internal data structures" do
      # Define a simple worker for this test
      simple_worker = Class.new do
        include Sidekiq::Job

        def perform(msg); end
      end
      stub_const("SimpleWorker", simple_worker)

      launcher = Sidekiq::Launcher.new(sidekiq_config)

      begin
        launcher.run

        # Enqueue a simple job
        SimpleWorker.perform_async("namespace_test")
        sleep 0.5

        # Check all keys are properly namespaced
        raw_redis = RedisClient.config(url: redis_url).new_client
        keys = raw_redis.call("KEYS", "*")

        # All keys should have namespace prefix
        expect(keys).to all(start_with("#{namespace}:"))

        # Should have queue-related keys
        queue_keys = keys.select { |k| k.include?("queue") }
        expect(queue_keys).not_to be_empty

        raw_redis.close
      ensure
        launcher.quiet
        launcher.stop
        Sidekiq.redis(&:flushdb)
      end
    end
  end
end
