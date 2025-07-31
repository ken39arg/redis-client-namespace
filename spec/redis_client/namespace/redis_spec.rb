# frozen_string_literal: true

RSpec.describe "RedisClient::Namespace use by redis-rb" do
  require "redis"

  let(:namespace) { "test_ns" }
  let(:builder) { RedisClient::Namespace.new(namespace) }
  let(:redis_host) { ENV.fetch("REDIS_HOST", "127.0.0.1") }
  let(:redis_port) { ENV.fetch("REDIS_PORT", "6379") }
  let(:redis_db) { ENV.fetch("REDIS_DB", "0") }
  let(:client) { Redis.new(host: redis_host, port: redis_port, db: redis_db, command_builder: builder) }
  let(:raw_client) { Redis.new(host: redis_host, port: redis_port, db: redis_db) }

  before do
    # Clean up any existing test keys
    raw_client.flushdb
  end

  after do
    # Clean up after each test
    raw_client.flushdb
  end

  describe "basic string operations" do
    it "prefixes keys with namespace" do
      client.set("key1", "value1")

      # Verify the namespaced key exists in Redis
      expect(raw_client.get("test_ns:key1")).to eq("value1")

      # Verify the original key doesn't exist
      expect(raw_client.get("key1")).to be_nil

      # Verify we can retrieve through the namespaced client
      expect(client.get("key1")).to eq("value1")
    end

    it "handles multiple keys" do
      client.mset(key1: "value1", key2: "value2")

      # Verify both namespaced keys exist
      expect(raw_client.mget("test_ns:key1", "test_ns:key2")).to eq(["value1", "value2"])

      # Verify retrieval through namespaced client
      expect(client.mget("key1", "key2")).to eq(["value1", "value2"])
    end
  end

  describe "list operations" do
    it "handles list commands correctly" do
      client.lpush(:mylist, ["item1", "item2"])

      # Verify the namespaced list exists
      expect(raw_client.llen("test_ns:mylist")).to eq(2)

      # Verify list contents through namespaced client
      expect(client.lrange("mylist", 0, -1)).to eq(["item2", "item1"])
    end
  end

  describe "set operations" do
    it "handles set operations" do
      client.sadd("myset", "member1", "member2")

      # Verify the namespaced set exists
      expect(raw_client.scard("test_ns:myset")).to eq(2)

      # Verify set membership through namespaced client
      expect(client.sismember("myset", "member1")).to eq(true)
      expect(client.smembers("myset")).to contain_exactly("member1", "member2")
    end

    it "handles set operations between multiple keys" do
      client.sadd("set1", "a", "b", "c")
      client.sadd("set2", "b", "c", "d")

      # Test set intersection
      result = client.sinter("set1", "set2")
      expect(result).to contain_exactly("b", "c")
    end
  end

  describe "hash operations" do
    it "handles hash commands" do
      client.hset("myhash", "field1", "value1", "field2", "value2")

      # Verify the namespaced hash exists
      expect(raw_client.hlen("test_ns:myhash")).to eq(2)

      # Verify hash contents through namespaced client
      expect(client.hget("myhash", "field1")).to eq("value1")
      expect(client.hgetall("myhash")).to eq({ "field1" => "value1", "field2" => "value2" })
    end
  end

  describe "sorted set operations" do
    it "handles sorted set commands" do
      client.zadd("myzset", [1, "member1", 2, "member2"])

      # Verify the namespaced sorted set exists
      expect(raw_client.zcard("test_ns:myzset")).to eq(2)

      # Verify sorted set contents through namespaced client
      expect(client.zrange("myzset", 0, -1)).to eq(["member1", "member2"])
      expect(client.zscore("myzset", "member1")).to eq(1.0)
    end
  end

  describe "key management operations" do
    it "handles EXISTS command" do
      client.set("existing_key", "value")

      expect(client.exists?("existing_key")).to eq(true)
      expect(client.exists?("non_existing_key")).to eq(false)

      # Verify the raw key doesn't exist without namespace
      expect(raw_client.exists?("existing_key")).to eq(false)
    end

    it "handles DEL command" do
      client.set("key1", "value1")
      client.set("key2", "value2")

      deleted_count = client.del("key1", "key2")
      expect(deleted_count).to eq(2)

      # Verify keys are deleted
      expect(client.exists?("key1")).to eq(false)
      expect(client.exists?("key2")).to eq(false)
    end

    it "handles RENAME command" do
      client.set("old_key", "value")

      client.rename("old_key", "new_key")

      expect(client.get("new_key")).to eq("value")
      expect(client.exists?("old_key")).to eq(false)

      # Verify the raw keys have namespaces
      expect(raw_client.get("test_ns:new_key")).to eq("value")
      expect(raw_client.exists?("test_ns:old_key")).to eq(false)
    end
  end

  describe "pattern matching operations" do
    it "handles KEYS command with patterns" do
      client.set("user:1", "john")
      client.set("user:2", "jane")
      client.set("admin:1", "alice")

      # KEYS returns the actual Redis keys with namespace prefix
      user_keys = client.keys("user:*")
      expect(user_keys).to contain_exactly("test_ns:user:1", "test_ns:user:2")

      all_keys = client.keys("*")
      expect(all_keys).to contain_exactly("test_ns:user:1", "test_ns:user:2", "test_ns:admin:1")
    end
  end

  describe "complex commands" do
    it "handles SORT command with patterns" do
      # Set up data for SORT
      client.lpush("mylist", ["1", "2", "3"])
      client.set("weight_1", "3")
      client.set("weight_2", "1")
      client.set("weight_3", "2")
      client.set("object_1", "first")
      client.set("object_2", "second")
      client.set("object_3", "third")

      # Test SORT with BY and GET patterns
      result = client.sort("mylist", by: "weight_*", get: "object_*")
      expect(result).to eq(["second", "third", "first"])
    end

    it "handles LUA scripts with key transformation" do
      # Simple LUA script that gets a key
      script = "return redis.call('get', KEYS[1])"

      client.set("mykey", "myvalue")

      # Execute script through namespaced client
      result = client.eval(script, keys: ["mykey"])
      expect(result).to eq("myvalue")

      # Verify the script accessed the namespaced key
      expect(raw_client.get("test_ns:mykey")).to eq("myvalue")
    end

    it "handles EVAL with multiple keys" do
      script = "return {redis.call('get', KEYS[1]), redis.call('get', KEYS[2])}"

      client.set("key1", "value1")
      client.set("key2", "value2")

      result = client.eval(script, keys: ["key1", "key2"])
      expect(result).to eq(["value1", "value2"])
    end
  end

  describe "transactions" do
    it "handles MULTI/EXEC with namespaced keys" do
      result = client.multi do |r|
        r.set("key1", "value1")
        r.incr("key2")
      end

      expect(result).to eq(["OK", 1])
      expect(client.get("key1")).to eq("value1")
      expect(client.get("key2")).to eq("1")
    end
  end

  describe "error handling" do
    it "warns for unknown commands and lets Redis handle the error" do
      # Capture stderr warning
      expect do
        expect { client.call("UNKNOWNCOMMAND", "arg1") }.to raise_error(Redis::CommandError)
      end.to output(/RedisClient::Namespace does not know how to handle 'UNKNOWNCOMMAND'/).to_stderr
    end
  end
end
