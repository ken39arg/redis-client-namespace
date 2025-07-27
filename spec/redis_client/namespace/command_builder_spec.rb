# frozen_string_literal: true

require "spec_helper"

RSpec.describe RedisClient::Namespace do
  let(:builder) { described_class.new("test") }
  let(:empty_builder) { described_class.new("") }

  describe "#generate" do
    context "basic commands" do
      it "adds namespace to GET command" do
        result = builder.generate(["GET", "key"])
        expect(result).to eq(["GET", "test:key"])
      end

      it "adds namespace to SET command" do
        result = builder.generate(["SET", "key", "value"])
        expect(result).to eq(["SET", "test:key", "value"])
      end

      it "processes multiple keys for DEL command" do
        result = builder.generate(["DEL", "key1", "key2", "key3"])
        expect(result).to eq(["DEL", "test:key1", "test:key2", "test:key3"])
      end

      it "processes multiple keys for EXISTS command" do
        result = builder.generate(["EXISTS", "key1", "key2"])
        expect(result).to eq(["EXISTS", "test:key1", "test:key2"])
      end

      it "processes multiple keys for MGET command" do
        result = builder.generate(["MGET", "key1", "key2", "key3"])
        expect(result).to eq(["MGET", "test:key1", "test:key2", "test:key3"])
      end

      it "processes multiple keys for UNLINK command" do
        result = builder.generate(["UNLINK", "key1", "key2", "key3"])
        expect(result).to eq(["UNLINK", "test:key1", "test:key2", "test:key3"])
      end
    end

    context "BLPOP/BRPOP commands" do
      it "correctly processes BLPOP command" do
        result = builder.generate(["BLPOP", "key1", "key2", "10"])
        expect(result).to eq(["BLPOP", "test:key1", "test:key2", "10"])
      end

      it "correctly processes BRPOP command" do
        result = builder.generate(["BRPOP", "key1", "30"])
        expect(result).to eq(["BRPOP", "test:key1", "30"])
      end
    end

    context "RPOPLPUSH/LMOVE commands" do
      it "correctly processes RPOPLPUSH command" do
        result = builder.generate(["RPOPLPUSH", "source", "destination"])
        expect(result).to eq(["RPOPLPUSH", "test:source", "test:destination"])
      end

      it "correctly processes LMOVE command" do
        result = builder.generate(["LMOVE", "source", "destination", "LEFT", "RIGHT"])
        expect(result).to eq(["LMOVE", "test:source", "test:destination", "LEFT", "RIGHT"])
      end
    end

    context "Pub/Sub commands" do
      it "processes multiple channels for SUBSCRIBE command" do
        result = builder.generate(["SUBSCRIBE", "channel1", "channel2", "channel3"])
        expect(result).to eq(["SUBSCRIBE", "test:channel1", "test:channel2", "test:channel3"])
      end

      it "processes multiple channels for UNSUBSCRIBE command" do
        result = builder.generate(["UNSUBSCRIBE", "channel1", "channel2"])
        expect(result).to eq(["UNSUBSCRIBE", "test:channel1", "test:channel2"])
      end

      it "processes multiple patterns for PSUBSCRIBE command" do
        result = builder.generate(["PSUBSCRIBE", "pattern*", "test*"])
        expect(result).to eq(["PSUBSCRIBE", "test:pattern*", "test:test*"])
      end

      it "processes multiple patterns for PUNSUBSCRIBE command" do
        result = builder.generate(["PUNSUBSCRIBE", "pattern*"])
        expect(result).to eq(["PUNSUBSCRIBE", "test:pattern*"])
      end
    end

    context "MSET/MSETNX commands" do
      it "correctly processes multiple keys for MSET" do
        result = builder.generate(["MSET", "key1", "val1", "key2", "val2"])
        expect(result).to eq(["MSET", "test:key1", "val1", "test:key2", "val2"])
      end

      it "correctly processes multiple keys for MSETNX" do
        result = builder.generate(["MSETNX", "key1", "val1", "key2", "val2", "key3", "val3"])
        expect(result).to eq(["MSETNX", "test:key1", "val1", "test:key2", "val2", "test:key3", "val3"])
      end

      it "doesn't crash with odd number of arguments for MSET (invalid command)" do
        result = builder.generate(["MSET", "key1", "val1", "key2"])
        expect(result).to eq(["MSET", "test:key1", "val1", "test:key2"])
      end
    end

    context "EVALSHA/EVAL commands" do
      it "processes normal EVAL command" do
        result = builder.generate(["EVAL", "script", "2", "key1", "key2", "arg1"])
        expect(result).to eq(["EVAL", "script", "2", "test:key1", "test:key2", "arg1"])
      end

      it "processes normal EVALSHA command" do
        result = builder.generate(["EVALSHA", "sha1hash", "1", "key1", "arg1", "arg2"])
        expect(result).to eq(["EVALSHA", "sha1hash", "1", "test:key1", "arg1", "arg2"])
      end

      it "processes when numkeys is 0" do
        result = builder.generate(["EVAL", "script", "0", "arg1", "arg2"])
        expect(result).to eq(["EVAL", "script", "0", "arg1", "arg2"])
      end

      it "doesn't crash when numkeys is greater than actual keys (bug case)" do
        result = builder.generate(["EVAL", "script", "5", "key1"])
        expect(result).to eq(["EVAL", "script", "5", "test:key1"])
      end

      it "doesn't crash when numkeys is negative" do
        result = builder.generate(["EVAL", "script", "-1", "key1"])
        expect(result).to eq(["EVAL", "script", "-1", "key1"])
      end

      it "doesn't crash when command is too short" do
        result = builder.generate(["EVAL", "script"])
        expect(result).to eq(["EVAL", "script"])
      end
    end

    context "SCRIPT commands" do
      it "SCRIPT command doesn't change keys" do
        result = builder.generate(["SCRIPT", "FLUSH"])
        expect(result).to eq(["SCRIPT", "FLUSH"])
      end

      it "SCRIPT LOAD command doesn't change keys" do
        result = builder.generate(["SCRIPT", "LOAD", "return 1"])
        expect(result).to eq(["SCRIPT", "LOAD", "return 1"])
      end
    end

    context "edge cases" do
      it "does nothing when namespace is empty" do
        result = empty_builder.generate(["GET", "key"])
        expect(result).to eq(["GET", "key"])
      end

      it "does nothing when namespace is nil" do
        nil_builder = described_class.new(nil)
        result = nil_builder.generate(["GET", "key"])
        expect(result).to eq(["GET", "key"])
      end

      it "processes single element command" do
        result = builder.generate(["PING"])
        expect(result).to eq(["PING"])
      end

      it "is case insensitive" do
        result = builder.generate(["get", "key"])
        expect(result).to eq(["get", "test:key"])
      end

      it "raises error for unknown commands" do
        expect {
          builder.generate(["UNKNOWN", "key", "value"])
        }.to raise_error(RuntimeError, "RedisClient::NamespaceCommandBuilder does not know how to handle 'UNKNOWN'.")
      end

      it "processes command passed as symbol" do
        result = builder.generate([:set, "foo", 1])
        expect(result).to eq(["set", "test:foo", "1"])
      end
    end

    context "special value handling" do
      it "processes empty string key" do
        result = builder.generate(["GET", ""])
        expect(result).to eq(["GET", "test:"])
      end

      it "processes numeric key" do
        result = builder.generate(["GET", 123])
        expect(result).to eq(["GET", "test:123"])
      end
    end

    context "new command processing" do
      # Hash commands
      it "processes HGET command" do
        result = builder.generate(["HGET", "hash", "field"])
        expect(result).to eq(["HGET", "test:hash", "field"])
      end

      it "HMGET command" do
        result = builder.generate(["HMGET", "hash", "field1", "field2"])
        expect(result).to eq(["HMGET", "test:hash", "field1", "field2"])
      end

      # Sorted Set commands
      it "ZADD command" do
        result = builder.generate(["ZADD", "zset", "1", "member1", "2", "member2"])
        expect(result).to eq(["ZADD", "test:zset", "1", "member1", "2", "member2"])
      end

      it "ZINTERSTORE command" do
        result = builder.generate(["ZINTERSTORE", "dest", "2", "key1", "key2"])
        expect(result).to eq(["ZINTERSTORE", "test:dest", "2", "test:key1", "test:key2"])
      end

      it "ZINTER command" do
        result = builder.generate(["ZINTER", "2", "zset1", "zset2", "WEIGHTS", "2", "3"])
        expect(result).to eq(["ZINTER", "2", "test:zset1", "test:zset2", "WEIGHTS", "2", "3"])
      end

      it "ZUNION command" do
        result = builder.generate(["ZUNION", "3", "zset1", "zset2", "zset3"])
        expect(result).to eq(["ZUNION", "3", "test:zset1", "test:zset2", "test:zset3"])
      end

      it "ZDIFF command" do
        result = builder.generate(["ZDIFF", "2", "zset1", "zset2", "WITHSCORES"])
        expect(result).to eq(["ZDIFF", "2", "test:zset1", "test:zset2", "WITHSCORES"])
      end

      # List commands
      it "LPUSH command" do
        result = builder.generate(["LPUSH", "list", "value1", "value2"])
        expect(result).to eq(["LPUSH", "test:list", "value1", "value2"])
      end

      it "BRPOPLPUSH command" do
        result = builder.generate(["BRPOPLPUSH", "source", "dest", "10"])
        expect(result).to eq(["BRPOPLPUSH", "test:source", "test:dest", "10"])
      end

      it "LMPOP command" do
        result = builder.generate(["LMPOP", "2", "list1", "list2", "LEFT"])
        expect(result).to eq(["LMPOP", "2", "test:list1", "test:list2", "LEFT"])
      end

      it "BLMPOP command" do
        result = builder.generate(["BLMPOP", "10", "2", "list1", "list2", "RIGHT"])
        expect(result).to eq(["BLMPOP", "10", "2", "test:list1", "test:list2", "RIGHT"])
      end

      # Set commands
      it "SADD command" do
        result = builder.generate(["SADD", "set", "member1", "member2"])
        expect(result).to eq(["SADD", "test:set", "member1", "member2"])
      end

      it "SINTER command" do
        result = builder.generate(["SINTER", "key1", "key2", "key3"])
        expect(result).to eq(["SINTER", "test:key1", "test:key2", "test:key3"])
      end

      it "SMOVE command" do
        result = builder.generate(["SMOVE", "source", "dest", "member"])
        expect(result).to eq(["SMOVE", "test:source", "test:dest", "member"])
      end

      # Key commands
      it "EXPIRE command" do
        result = builder.generate(["EXPIRE", "key", "300"])
        expect(result).to eq(["EXPIRE", "test:key", "300"])
      end

      it "RENAME command" do
        result = builder.generate(["RENAME", "oldkey", "newkey"])
        expect(result).to eq(["RENAME", "test:oldkey", "test:newkey"])
      end

      it "TTL command" do
        result = builder.generate(["TTL", "key"])
        expect(result).to eq(["TTL", "test:key"])
      end

      # Scan commands
      it "SCAN command" do
        result = builder.generate(["SCAN", "0"])
        expect(result).to eq(["SCAN", "0"])
      end

      it "processes SCAN command with MATCH option" do
        result = builder.generate(["SCAN", "0", "MATCH", "prefix*", "COUNT", "10"])
        expect(result).to eq(["SCAN", "0", "MATCH", "test:prefix*", "COUNT", "10"])
      end

      it "HSCAN command" do
        result = builder.generate(["HSCAN", "hash", "0", "MATCH", "field*"])
        expect(result).to eq(["HSCAN", "test:hash", "0", "MATCH", "test:field*"])
      end

      it "HSCAN command without MATCH option" do
        result = builder.generate(["HSCAN", "hash", "0"])
        expect(result).to eq(["HSCAN", "test:hash", "0"])
      end

      it "SCAN command without MATCH option" do
        result = builder.generate(["SCAN", "0", "COUNT", "10"])
        expect(result).to eq(["SCAN", "0", "COUNT", "10"])
      end

      # Stream commands
      it "XADD command" do
        result = builder.generate(["XADD", "stream", "*", "field", "value"])
        expect(result).to eq(["XADD", "test:stream", "*", "field", "value"])
      end

      it "XREAD command" do
        result = builder.generate(["XREAD", "COUNT", "10", "STREAMS", "stream1", "stream2", "0-0", "0-0"])
        expect(result).to eq(["XREAD", "COUNT", "10", "STREAMS", "test:stream1", "test:stream2", "0-0", "0-0"])
      end

      it "XGROUP command" do
        result = builder.generate(["XGROUP", "CREATE", "stream", "group", "0"])
        expect(result).to eq(["XGROUP", "CREATE", "test:stream", "group", "0"])
      end

      # Geo commands
      it "GEOADD command" do
        result = builder.generate(["GEOADD", "key", "13.361389", "38.115556", "Palermo"])
        expect(result).to eq(["GEOADD", "test:key", "13.361389", "38.115556", "Palermo"])
      end

      it "GEORADIUS command" do
        result = builder.generate(["GEORADIUS", "key", "15", "37", "200", "km"])
        expect(result).to eq(["GEORADIUS", "test:key", "15", "37", "200", "km"])
      end

      it "processes GEORADIUS command with STORE option" do
        result = builder.generate(["GEORADIUS", "key", "15", "37", "200", "km", "STORE", "dest"])
        expect(result).to eq(["GEORADIUS", "test:key", "15", "37", "200", "km", "STORE", "test:dest"])
      end

      # SORT command
      it "SORT command" do
        result = builder.generate(["SORT", "list"])
        expect(result).to eq(["SORT", "test:list"])
      end

      it "processes SORT command with BY, GET, STORE options" do
        result = builder.generate(["SORT", "list", "BY", "weight_*", "GET", "object_*", "STORE", "result"])
        expect(result).to eq(["SORT", "test:list", "BY", "test:weight_*", "GET", "test:object_*", "STORE", "test:result"])
      end

      it "processes SORT command with GET #" do
        result = builder.generate(["SORT", "list", "GET", "#"])
        expect(result).to eq(["SORT", "test:list", "GET", "#"])
      end

      # Transaction commands
      it "WATCH command" do
        result = builder.generate(["WATCH", "key1", "key2"])
        expect(result).to eq(["WATCH", "test:key1", "test:key2"])
      end

      # HyperLogLog commands
      it "PFADD command" do
        result = builder.generate(["PFADD", "hll", "a", "b", "c"])
        expect(result).to eq(["PFADD", "test:hll", "a", "b", "c"])
      end

      it "PFCOUNT command" do
        result = builder.generate(["PFCOUNT", "hll1", "hll2"])
        expect(result).to eq(["PFCOUNT", "test:hll1", "test:hll2"])
      end

      it "PFMERGE command" do
        result = builder.generate(["PFMERGE", "dest", "src1", "src2"])
        expect(result).to eq(["PFMERGE", "test:dest", "test:src1", "test:src2"])
      end

      # Commands that should not transform
      it "PING command doesn't change keys" do
        result = builder.generate(["PING"])
        expect(result).to eq(["PING"])
      end

      it "PING command with arguments doesn't change keys" do
        result = builder.generate(["PING", "hello"])
        expect(result).to eq(["PING", "hello"])
      end

      it "FLUSHDB command doesn't change keys" do
        result = builder.generate(["FLUSHDB", "ASYNC"])
        expect(result).to eq(["FLUSHDB", "ASYNC"])
      end

      it "INFO command doesn't change keys" do
        result = builder.generate(["INFO", "replication"])
        expect(result).to eq(["INFO", "replication"])
      end

      it "CONFIG command doesn't change keys" do
        result = builder.generate(["CONFIG", "GET", "*"])
        expect(result).to eq(["CONFIG", "GET", "*"])
      end

      it "CLIENT command doesn't change keys" do
        result = builder.generate(["CLIENT", "LIST"])
        expect(result).to eq(["CLIENT", "LIST"])
      end

      it "WAIT command doesn't change keys" do
        result = builder.generate(["WAIT", "1", "1000"])
        expect(result).to eq(["WAIT", "1", "1000"])
      end

      it "CLUSTER command doesn't change keys" do
        result = builder.generate(["CLUSTER", "INFO"])
        expect(result).to eq(["CLUSTER", "INFO"])
      end

      it "HELLO command doesn't change keys" do
        result = builder.generate(["HELLO", "3"])
        expect(result).to eq(["HELLO", "3"])
      end

      it "ACL command doesn't change keys" do
        result = builder.generate(["ACL", "LIST"])
        expect(result).to eq(["ACL", "LIST"])
      end

      # Other commands
      it "COPY command" do
        result = builder.generate(["COPY", "source", "dest"])
        expect(result).to eq(["COPY", "test:source", "test:dest"])
      end

      it "COPY command with REPLACE option" do
        result = builder.generate(["COPY", "source", "dest", "REPLACE"])
        expect(result).to eq(["COPY", "test:source", "test:dest", "REPLACE"])
      end

      it "MIGRATE command with single key" do
        result = builder.generate(["MIGRATE", "127.0.0.1", "6379", "key", "0", "1000"])
        expect(result).to eq(["MIGRATE", "127.0.0.1", "6379", "test:key", "0", "1000"])
      end

      it "MIGRATE command with KEYS option" do
        result = builder.generate(["MIGRATE", "127.0.0.1", "6379", "", "0", "1000", "KEYS", "key1", "key2", "key3"])
        expect(result).to eq(["MIGRATE", "127.0.0.1", "6379", "", "0", "1000", "KEYS", "test:key1", "test:key2", "test:key3"])
      end

      it "PUBSUB CHANNELS command" do
        result = builder.generate(["PUBSUB", "CHANNELS", "pattern*"])
        expect(result).to eq(["PUBSUB", "CHANNELS", "test:pattern*"])
      end

      it "PUBSUB NUMSUB command with multiple channels" do
        result = builder.generate(["PUBSUB", "NUMSUB", "channel1", "channel2", "channel3"])
        expect(result).to eq(["PUBSUB", "NUMSUB", "test:channel1", "test:channel2", "test:channel3"])
      end

      it "PUBSUB NUMPAT command" do
        result = builder.generate(["PUBSUB", "NUMPAT"])
        expect(result).to eq(["PUBSUB", "NUMPAT"])
      end

      it "PUBSUB SHARDNUMSUB command with multiple channels" do
        result = builder.generate(["PUBSUB", "SHARDNUMSUB", "shard1", "shard2"])
        expect(result).to eq(["PUBSUB", "SHARDNUMSUB", "test:shard1", "test:shard2"])
      end
    end
  end

  describe "#rename_key" do
    it "adds prefix when namespace is present" do
      expect(builder.send(:rename_key, "key")).to eq("test:key")
    end

    it "returns as-is when namespace is empty" do
      expect(empty_builder.send(:rename_key, "key")).to eq("key")
    end
  end
end
