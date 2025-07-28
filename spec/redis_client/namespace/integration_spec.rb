# frozen_string_literal: true

RSpec.describe RedisClient::Namespace do
  let(:namespace) { "test_ns" }
  let(:builder) { described_class.new(namespace) }
  let(:redis_host) { ENV.fetch("REDIS_HOST", "127.0.0.1") }
  let(:redis_port) { ENV.fetch("REDIS_PORT", "6379") }
  let(:redis_db) { ENV.fetch("REDIS_DB", "0") }
  let(:client) { RedisClient.config(host: redis_host, port: redis_port, db: redis_db, command_builder: builder).new_client }
  let(:raw_client) { RedisClient.config(host: redis_host, port: redis_port, db: redis_db).new_client }

  before do
    # Clean up any existing test keys
    raw_client.call("FLUSHDB")
  end

  after do
    # Clean up after each test
    raw_client.call("FLUSHDB")
  end

  describe "basic string operations" do
    it "prefixes keys with namespace" do
      client.call("SET", "key1", "value1")

      # Verify the namespaced key exists in Redis
      expect(raw_client.call("GET", "test_ns:key1")).to eq("value1")

      # Verify the original key doesn't exist
      expect(raw_client.call("GET", "key1")).to be_nil

      # Verify we can retrieve through the namespaced client
      expect(client.call("GET", "key1")).to eq("value1")
    end

    it "handles multiple keys" do
      client.call("MSET", "key1", "value1", "key2", "value2")

      # Verify both namespaced keys exist
      expect(raw_client.call("GET", "test_ns:key1")).to eq("value1")
      expect(raw_client.call("GET", "test_ns:key2")).to eq("value2")

      # Verify retrieval through namespaced client
      expect(client.call("MGET", "key1", "key2")).to eq(["value1", "value2"])
    end
  end

  describe "list operations" do
    it "handles list commands correctly" do
      client.call("LPUSH", "mylist", "item1", "item2")

      # Verify the namespaced list exists
      expect(raw_client.call("LLEN", "test_ns:mylist")).to eq(2)

      # Verify list contents through namespaced client
      expect(client.call("LRANGE", "mylist", 0, -1)).to eq(["item2", "item1"])
    end
  end

  describe "set operations" do
    it "handles set operations" do
      client.call("SADD", "myset", "member1", "member2")

      # Verify the namespaced set exists
      expect(raw_client.call("SCARD", "test_ns:myset")).to eq(2)

      # Verify set membership through namespaced client
      expect(client.call("SISMEMBER", "myset", "member1")).to eq(1)
      expect(client.call("SMEMBERS", "myset")).to contain_exactly("member1", "member2")
    end

    it "handles set operations between multiple keys" do
      client.call("SADD", "set1", "a", "b", "c")
      client.call("SADD", "set2", "b", "c", "d")

      # Test set intersection
      result = client.call("SINTER", "set1", "set2")
      expect(result).to contain_exactly("b", "c")
    end
  end

  describe "hash operations" do
    it "handles hash commands" do
      client.call("HSET", "myhash", "field1", "value1", "field2", "value2")

      # Verify the namespaced hash exists
      expect(raw_client.call("HLEN", "test_ns:myhash")).to eq(2)

      # Verify hash contents through namespaced client
      expect(client.call("HGET", "myhash", "field1")).to eq("value1")
      expect(client.call("HGETALL", "myhash")).to eq({ "field1" => "value1", "field2" => "value2" })
    end
  end

  describe "sorted set operations" do
    it "handles sorted set commands" do
      client.call("ZADD", "myzset", 1, "member1", 2, "member2")

      # Verify the namespaced sorted set exists
      expect(raw_client.call("ZCARD", "test_ns:myzset")).to eq(2)

      # Verify sorted set contents through namespaced client
      expect(client.call("ZRANGE", "myzset", 0, -1)).to eq(["member1", "member2"])
      expect(client.call("ZSCORE", "myzset", "member1")).to eq(1.0)
    end
  end

  describe "key management operations" do
    it "handles EXISTS command" do
      client.call("SET", "existing_key", "value")

      expect(client.call("EXISTS", "existing_key")).to eq(1)
      expect(client.call("EXISTS", "non_existing_key")).to eq(0)

      # Verify the raw key doesn't exist without namespace
      expect(raw_client.call("EXISTS", "existing_key")).to eq(0)
    end

    it "handles DEL command" do
      client.call("SET", "key1", "value1")
      client.call("SET", "key2", "value2")

      deleted_count = client.call("DEL", "key1", "key2")
      expect(deleted_count).to eq(2)

      # Verify keys are deleted
      expect(client.call("EXISTS", "key1")).to eq(0)
      expect(client.call("EXISTS", "key2")).to eq(0)
    end

    it "handles RENAME command" do
      client.call("SET", "old_key", "value")

      client.call("RENAME", "old_key", "new_key")

      expect(client.call("GET", "new_key")).to eq("value")
      expect(client.call("EXISTS", "old_key")).to eq(0)

      # Verify the raw keys have namespaces
      expect(raw_client.call("GET", "test_ns:new_key")).to eq("value")
      expect(raw_client.call("EXISTS", "test_ns:old_key")).to eq(0)
    end
  end

  describe "pattern matching operations" do
    it "handles KEYS command with patterns" do
      client.call("SET", "user:1", "john")
      client.call("SET", "user:2", "jane")
      client.call("SET", "admin:1", "alice")

      # KEYS returns the actual Redis keys with namespace prefix
      user_keys = client.call("KEYS", "user:*")
      expect(user_keys).to contain_exactly("test_ns:user:1", "test_ns:user:2")

      all_keys = client.call("KEYS", "*")
      expect(all_keys).to contain_exactly("test_ns:user:1", "test_ns:user:2", "test_ns:admin:1")
    end
  end

  describe "custom separator" do
    let(:custom_builder) { described_class.new("app", separator: "-") }
    let(:custom_client) { RedisClient.config(host: redis_host, port: redis_port, db: redis_db, command_builder: custom_builder).new_client }

    it "uses custom separator" do
      custom_client.call("SET", "key1", "value1")

      # Verify the key exists with custom separator
      expect(raw_client.call("GET", "app-key1")).to eq("value1")
      expect(custom_client.call("GET", "key1")).to eq("value1")
    end
  end

  describe "nested namespaces" do
    let(:parent_builder) { described_class.new("parent") }
    let(:child_builder) { described_class.new("child", parent_command_builder: parent_builder) }
    let(:nested_client) { RedisClient.config(host: redis_host, port: redis_port, db: redis_db, command_builder: child_builder).new_client }

    it "applies nested namespaces" do
      nested_client.call("SET", "key1", "value1")

      # Verify the key exists with nested namespace
      expect(raw_client.call("GET", "child:parent:key1")).to eq("value1")
      expect(nested_client.call("GET", "key1")).to eq("value1")
    end
  end

  describe "complex commands" do
    it "handles SORT command with patterns" do
      # Set up data for SORT
      client.call("LPUSH", "mylist", "1", "2", "3")
      client.call("SET", "weight_1", "3")
      client.call("SET", "weight_2", "1")
      client.call("SET", "weight_3", "2")
      client.call("SET", "object_1", "first")
      client.call("SET", "object_2", "second")
      client.call("SET", "object_3", "third")

      # Test SORT with BY and GET patterns
      result = client.call("SORT", "mylist", "BY", "weight_*", "GET", "object_*")
      expect(result).to eq(["second", "third", "first"])
    end

    it "handles LUA scripts with key transformation" do
      # Simple LUA script that gets a key
      script = "return redis.call('get', KEYS[1])"

      client.call("SET", "mykey", "myvalue")

      # Execute script through namespaced client
      result = client.call("EVAL", script, 1, "mykey")
      expect(result).to eq("myvalue")

      # Verify the script accessed the namespaced key
      expect(raw_client.call("GET", "test_ns:mykey")).to eq("myvalue")
    end

    it "handles EVAL with multiple keys" do
      script = "return {redis.call('get', KEYS[1]), redis.call('get', KEYS[2])}"

      client.call("SET", "key1", "value1")
      client.call("SET", "key2", "value2")

      result = client.call("EVAL", script, 2, "key1", "key2")
      expect(result).to eq(["value1", "value2"])
    end
  end

  describe "transactions" do
    it "handles MULTI/EXEC with namespaced keys" do
      result = client.multi do |r|
        r.call("SET", "key1", "value1")
        r.call("INCR", "key2")
      end

      expect(result).to eq(["OK", 1])
      expect(client.call("GET", "key1")).to eq("value1")
      expect(client.call("GET", "key2")).to eq("1")
    end
  end

  describe "error handling" do
    it "raises error for unknown commands" do
      expect do
        client.call("UNKNOWNCOMMAND", "arg1")
      end.to raise_error(RedisClient::Namespace::Error, /does not know how to handle 'UNKNOWNCOMMAND'/)
    end
  end
end
