# frozen_string_literal: true

RSpec.describe RedisClient::Namespace do
  let(:builder) { described_class.new("test") }

  describe "manual test commands" do
    # These commands have complex patterns that need manual testing
    # manual_test_commands = %w[
    #   SUBSCRIBE UNSUBSCRIBE PSUBSCRIBE PUNSUBSCRIBE
    #   PUBLISH PUBSUB
    #   XREAD XREADGROUP
    #   GEORADIUS GEORADIUSBYMEMBER
    #   MIGRATE
    # ]

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

      it "PUBLISH command applies namespace to channel name" do
        result = builder.generate(["PUBLISH", "channel", "message"])
        expect(result).to eq(["PUBLISH", "test:channel", "message"])
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

    context "Stream commands" do
      it "XREAD command" do
        result = builder.generate(["XREAD", "COUNT", "10", "STREAMS", "stream1", "stream2", "0-0", "0-0"])
        expect(result).to eq(["XREAD", "COUNT", "10", "STREAMS", "test:stream1", "test:stream2", "0-0", "0-0"])
      end

      it "XREADGROUP command applies namespace to stream keys" do
        result = builder.generate(["XREADGROUP", "GROUP", "mygroup", "consumer1", "STREAMS", "stream1", "stream2", ">", ">"])
        expect(result).to eq(["XREADGROUP", "GROUP", "mygroup", "consumer1", "STREAMS", "test:stream1", "test:stream2", ">", ">"])
      end

      it "XREADGROUP handles COUNT and BLOCK options" do
        result = builder.generate(["XREADGROUP", "GROUP", "mygroup", "consumer1", "COUNT", "10", "BLOCK", "1000", "STREAMS", "stream1", ">"])
        expect(result).to eq(["XREADGROUP", "GROUP", "mygroup", "consumer1", "COUNT", "10", "BLOCK", "1000", "STREAMS", "test:stream1", ">"])
      end
    end

    context "Geo commands" do
      it "GEORADIUS command" do
        result = builder.generate(["GEORADIUS", "key", "15", "37", "200", "km"])
        expect(result).to eq(["GEORADIUS", "test:key", "15", "37", "200", "km"])
      end

      it "processes GEORADIUS command with STORE option" do
        result = builder.generate(["GEORADIUS", "key", "15", "37", "200", "km", "STORE", "dest"])
        expect(result).to eq(["GEORADIUS", "test:key", "15", "37", "200", "km", "STORE", "test:dest"])
      end

      it "GEORADIUSBYMEMBER command applies namespace to key and member references" do
        result = builder.generate(["GEORADIUSBYMEMBER", "key", "member", "100", "km"])
        expect(result).to eq(["GEORADIUSBYMEMBER", "test:key", "member", "100", "km"])
      end

      it "GEORADIUSBYMEMBER handles STORE option" do
        result = builder.generate(["GEORADIUSBYMEMBER", "key", "member", "100", "km", "STORE", "dest"])
        expect(result).to eq(["GEORADIUSBYMEMBER", "test:key", "member", "100", "km", "STORE", "test:dest"])
      end

      it "GEORADIUSBYMEMBER handles STOREDIST option" do
        result = builder.generate(["GEORADIUSBYMEMBER", "key", "member", "100", "km", "STOREDIST", "dest"])
        expect(result).to eq(["GEORADIUSBYMEMBER", "test:key", "member", "100", "km", "STOREDIST", "test:dest"])
      end
    end

    context "MIGRATE command" do
      it "MIGRATE command with single key" do
        result = builder.generate(["MIGRATE", "127.0.0.1", "6379", "key", "0", "1000"])
        expect(result).to eq(["MIGRATE", "127.0.0.1", "6379", "test:key", "0", "1000"])
      end

      it "MIGRATE command with KEYS option" do
        result = builder.generate(["MIGRATE", "127.0.0.1", "6379", "", "0", "1000", "KEYS", "key1", "key2", "key3"])
        expect(result).to eq(["MIGRATE", "127.0.0.1", "6379", "", "0", "1000", "KEYS", "test:key1", "test:key2", "test:key3"])
      end
    end
  end
end
