# frozen_string_literal: true

RSpec.describe "RedisClient::Namespace use by redis-client" do
  let(:namespace) { "test_ns" }
  let(:redis_connection_config) do
    {
      host: ENV.fetch("REDIS_HOST", "127.0.0.1"),
      port: ENV.fetch("REDIS_PORT", "6379"),
      db: ENV.fetch("REDIS_DB", "0")
    }
  end
  let(:client) do
    RedisClient.config(
      **redis_connection_config,
      middlewares: [RedisClient::Namespace::Middleware],
      custom: { namespace: namespace, separator: ":" }
    ).new_client
  end
  let(:raw_client) { RedisClient.config(**redis_connection_config).new_client }

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
      expect(raw_client.call("GET", "#{namespace}:key1")).to eq("value1")

      # Verify the original key doesn't exist
      expect(raw_client.call("GET", "key1")).to be_nil

      # Verify we can retrieve through the namespaced client
      expect(client.call("GET", "key1")).to eq("value1")
    end

    it "handles multiple keys" do
      client.call("MSET", "key1", "value1", "key2", "value2")

      # Verify both namespaced keys exist
      expect(raw_client.call("GET", "#{namespace}:key1")).to eq("value1")
      expect(raw_client.call("GET", "#{namespace}:key2")).to eq("value2")

      # Verify retrieval through namespaced client
      expect(client.call("MGET", "key1", "key2")).to eq(["value1", "value2"])
    end

    it "with" do
      client.with do |r|
        expect(r.call("SET", "mykey", "hello world")).to eq("OK")
        expect(r.call("GET", "mykey")).to eq("hello world")
      end
      expect(raw_client.call("GET", "#{namespace}:mykey")).to eq("hello world")
    end

    it "Type support" do
      client.call("SET", "integer1", 12)
      client.call("SET", "double1", 1.23)

      expect(client.call("GET", "integer1")).to eq "12"
      expect(client.call("GET", "double1")).to eq "1.23"
    end
  end

  describe "list operations" do
    it "handles list commands correctly" do
      client.call("LPUSH", "mylist", "item1", "item2")

      # Verify the namespaced list exists
      expect(raw_client.call("LLEN", "#{namespace}:mylist")).to eq(2)

      # Verify list contents through namespaced client
      expect(client.call("LRANGE", "mylist", 0, -1)).to eq(["item2", "item1"])
    end

    it "Type support" do
      client.call("RPUSH", "mylist", [1, 2, 3], 4)
      expect(client.call("LRANGE", "mylist", 0, -1)).to eq(["1", "2", "3", "4"])
      expect(raw_client.call("LRANGE", "#{namespace}:mylist", 0, -1)).to eq(["1", "2", "3", "4"])
    end
  end

  describe "set operations" do
    it "handles set operations" do
      client.call("SADD", "myset", "member1", "member2")

      # Verify the namespaced set exists
      expect(raw_client.call("SCARD", "#{namespace}:myset")).to eq(2)

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
      expect(raw_client.call("HLEN", "#{namespace}:myhash")).to eq(2)

      # Verify hash contents through namespaced client
      expect(client.call("HGET", "myhash", "field1")).to eq("value1")
      expect(client.call("HGETALL", "myhash")).to eq({ "field1" => "value1", "field2" => "value2" })
    end
  end

  describe "sorted set operations" do
    it "handles sorted set commands" do
      client.call("ZADD", "myzset", 1, "member1", 2, "member2")

      # Verify the namespaced sorted set exists
      expect(raw_client.call("ZCARD", "#{namespace}:myzset")).to eq(2)

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
      expect(raw_client.call("GET", "#{namespace}:new_key")).to eq("value")
      expect(raw_client.call("EXISTS", "#{namespace}:old_key")).to eq(0)
    end
  end

  describe "pattern matching operations" do
    it "handles KEYS command with patterns" do
      client.call("SET", "user:1", "john")
      client.call("SET", "user:2", "jane")
      client.call("SET", "admin:1", "alice")

      # KEYS returns keys without namespace prefix
      user_keys = client.call("KEYS", "user:*")
      expect(user_keys).to contain_exactly("user:1", "user:2")

      all_keys = client.call("KEYS", "*")
      expect(all_keys).to contain_exactly("user:1", "user:2", "admin:1")
    end
  end

  describe "custom separator" do
    let(:custom_client) { RedisClient.config(**redis_connection_config, middlewares: [RedisClient::Namespace::Middleware], custom: { namespace: "app", separator: "-" }).new_client }

    it "uses custom separator" do
      custom_client.call("SET", "key1", "value1")

      # Verify the key exists with custom separator
      expect(raw_client.call("GET", "app-key1")).to eq("value1")
      expect(custom_client.call("GET", "key1")).to eq("value1")
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
      expect(raw_client.call("GET", "#{namespace}:mykey")).to eq("myvalue")
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

  describe "pipelining" do
    it "handles pipelined commands with namespaced keys" do
      result = client.pipelined do |pipeline|
        pipeline.call("SET", "foo", "bar")
        pipeline.call("INCR", "baz")
      end

      expect(result).to eq(["OK", 1])
      expect(client.call("GET", "foo")).to eq("bar")
      expect(client.call("GET", "baz")).to eq("1")
      expect(raw_client.call("GET", "#{namespace}:foo")).to eq("bar")
      expect(raw_client.call("GET", "#{namespace}:baz")).to eq("1")
    end

    it "handles pipelined commands with exception: false" do
      results = client.pipelined(exception: false) do |pipeline|
        pipeline.call("SET", "foo", "bar")
        pipeline.call("DOESNOTEXIST", 12)
        pipeline.call("SET", "baz", "qux")
      end

      expect(results[0]).to eq("OK")
      expect(results[1]).to be_a(RedisClient::CommandError)
      expect(results[2]).to eq("OK")
      expect(client.call("GET", "foo")).to eq("bar")
      expect(client.call("GET", "baz")).to eq("qux")
    end
  end

  describe "blocking commands" do
    it "handles blocking_call with timeout" do
      client.call("LPUSH", "mylist", "item1")

      result = client.blocking_call(1.0, "BRPOP", "mylist", 0)
      expect(result).to eq(["mylist", "item1"])
    end

    it "handles BLPOP with namespaced keys" do
      client.call("LPUSH", "list1", "a")
      client.call("LPUSH", "list2", "b")

      result = client.blocking_call(1.0, "BLPOP", "list1", "list2", 0)
      expect(result).to eq(["list1", "a"])

      result = client.blocking_call(1.0, "BLPOP", "list1", "list2", 0)
      expect(result).to eq(["list2", "b"])
    end

    it "raises timeout error when blocking call times out" do
      expect do
        client.blocking_call(0.1, "BRPOP", "empty_list", 0)
      end.to raise_error(RedisClient::ReadTimeoutError)
    end
  end

  describe "scan commands" do
    it "handles SCAN with block" do
      10.times { |i| client.call("SET", "key:#{i}", "value#{i}") }

      keys = []
      client.scan("MATCH", "key:*") do |key|
        keys << key
      end

      expect(keys.sort).to eq((0..9).map { |i| "key:#{i}" })
    end

    it "handles HSCAN with block" do
      10.times { |i| client.call("HSET", "myhash", "field:#{i}", "value#{i}") }

      fields = {}
      client.hscan("myhash", match: "field:*") do |field, value|
        fields[field] = value
      end

      expect(fields.keys.sort).to eq((0..9).map { |i| "field:#{i}" })
      expect(fields["field:5"]).to eq("value5")
    end

    it "handles SSCAN with block" do
      10.times { |i| client.call("SADD", "myset", "member:#{i}") }

      members = []
      client.sscan("myset", match: "member:*") do |member|
        members << member
      end

      expect(members.sort).to eq((0..9).map { |i| "member:#{i}" })
    end

    it "handles ZSCAN with block" do
      10.times { |i| client.call("ZADD", "myzset", i, "member:#{i}") }

      members = {}
      client.zscan("myzset", match: "member:*") do |member, score|
        members[member] = score
      end

      expect(members.keys.sort).to eq((0..9).map { |i| "member:#{i}" })
      expect(members["member:5"]).to eq("5")
    end
  end

  describe "type conversion" do
    it "converts result with block" do
      client.call("SET", "counter", "42")

      result = client.call("GET", "counter", &:to_i)
      expect(result).to eq(42)
      expect(result).to be_a(Integer)
    end

    it "converts hash values with block" do
      client.call("HSET", "myhash", "count", "100")

      result = client.call("HGET", "myhash", "count", &:to_i)
      expect(result).to eq(100)
    end

    it "works with custom conversion blocks" do
      client.call("SET", "data", "hello,world")

      result = client.call("GET", "data") { |v| v.split(",") }
      expect(result).to eq(["hello", "world"])
    end
  end

  describe "call_v methods" do
    it "handles call_v with array arguments" do
      args = ["SET", "mykey", "myvalue"]
      result = client.call_v(args)
      expect(result).to eq("OK")
      expect(client.call("GET", "mykey")).to eq("myvalue")
    end

    it "handles call_v with dynamic key list" do
      client.call("SET", "key1", "value1")
      client.call("SET", "key2", "value2")
      client.call("SET", "key3", "value3")

      keys = ["key1", "key2", "key3"]
      result = client.call_v(["MGET"] + keys)
      expect(result).to eq(["value1", "value2", "value3"])
    end

    it "handles call_once_v with array arguments" do
      args = ["GET", "mykey"]
      client.call("SET", "mykey", "test")
      result = client.call_once_v(args)
      expect(result).to eq("test")
    end

    it "handles blocking_call_v with array arguments" do
      client.call("LPUSH", "mylist", "item")
      args = ["BRPOP", "mylist", 0]
      result = client.blocking_call_v(1.0, args)
      expect(result).to eq(["mylist", "item"])
    end

    it "handles call_v in pipelined block" do
      result = client.pipelined do |pipeline|
        pipeline.call_v(["SET", "key1", "value1"])
        pipeline.call_v(["SET", "key2", "value2"])
        pipeline.call_v(["MGET", "key1", "key2"])
      end
      expect(result).to eq(["OK", "OK", ["value1", "value2"]])
    end

    it "handles call_v with complex data structures" do
      args = ["HSET", "myhash", "field1", "value1", "field2", "value2"]
      result = client.call_v(args)
      expect(result).to eq(2)

      args = ["HGETALL", "myhash"]
      result = client.call_v(args)
      expect(result).to eq({ "field1" => "value1", "field2" => "value2" })
    end
  end

  describe "pubsub" do
    xit "handles pubsub subscribe and publish with namespace (not supported by middleware)" do
      received_messages = []
      subscriber_ready = false

      # Start subscriber in a thread
      subscriber_thread = Thread.new do
        subscriber = RedisClient.config(**redis_connection_config, middlewares: [RedisClient::Namespace::Middleware], custom: { namespace: namespace, separator: ":" }).new_client
        pubsub = subscriber.pubsub

        pubsub.call("SUBSCRIBE", "channel1")
        subscriber_ready = true

        # Receive messages
        pubsub.next_event(1.0) # Skip subscription confirmation

        2.times do
          event = pubsub.next_event(1.0)
          received_messages << { channel: event[1], message: event[2] } if event && event[0] == "message"
        end

        pubsub.close
        subscriber.close
      end

      # Wait for subscriber to be ready
      sleep 0.1 until subscriber_ready

      # Publish messages
      publisher = RedisClient.config(**redis_connection_config, middlewares: [RedisClient::Namespace::Middleware], custom: { namespace: namespace, separator: ":" }).new_client
      publisher.call("PUBLISH", "channel1", "hello")
      publisher.call("PUBLISH", "channel1", "world")
      publisher.close

      # Wait for subscriber thread
      subscriber_thread.join(2.0)

      # Verify messages were received with namespaced channel
      expect(received_messages).to eq([
                                        { channel: "channel1", message: "hello" },
                                        { channel: "channel1", message: "world" }
                                      ])
    end

    xit "handles psubscribe with pattern matching (not supported by middleware)" do
      received_messages = []
      subscriber_ready = false

      subscriber_thread = Thread.new do
        subscriber = RedisClient.config(**redis_connection_config, middlewares: [RedisClient::Namespace::Middleware], custom: { namespace: namespace, separator: ":" }).new_client
        pubsub = subscriber.pubsub

        pubsub.call("PSUBSCRIBE", "channel:*")
        subscriber_ready = true

        # Skip subscription confirmation
        pubsub.next_event(1.0)

        # Receive messages
        3.times do
          event = pubsub.next_event(1.0)
          if event && event[0] == "pmessage"
            received_messages << { pattern: event[1], channel: event[2], message: event[3] }
          end
        end

        pubsub.close
        subscriber.close
      end

      # Wait for subscriber
      sleep 0.1 until subscriber_ready

      # Publish to different channels
      publisher = RedisClient.config(**redis_connection_config, middlewares: [RedisClient::Namespace::Middleware], custom: { namespace: namespace, separator: ":" }).new_client
      publisher.call("PUBLISH", "channel:1", "msg1")
      publisher.call("PUBLISH", "channel:2", "msg2")
      publisher.call("PUBLISH", "other", "msg3") # This should not be received
      publisher.call("PUBLISH", "channel:3", "msg4")
      publisher.close

      subscriber_thread.join(2.0)

      # Verify pattern-matched messages
      expect(received_messages).to eq([
                                        { pattern: "channel:*", channel: "channel:1", message: "msg1" },
                                        { pattern: "channel:*", channel: "channel:2", message: "msg2" },
                                        { pattern: "channel:*", channel: "channel:3", message: "msg4" }
                                      ])
    end
  end

  describe "error handling" do
    it "warns for unknown commands and lets Redis handle the error" do
      # Capture stderr warning
      expect do
        expect { client.call("UNKNOWNCOMMAND", "arg1") }.to raise_error(RedisClient::CommandError)
      end.to output(/RedisClient::Namespace does not know how to handle 'UNKNOWNCOMMAND'/).to_stderr
    end
  end
end
