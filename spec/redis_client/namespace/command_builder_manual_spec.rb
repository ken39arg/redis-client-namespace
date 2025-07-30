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
    #   HSCAN SSCAN ZSCAN
    #   SORT SORT_RO
    # ]
    testcases = {
      "SUBSCRIBE" => [
        {
          pattern: "basic",
          inputs: %w[SUBSCRIBE channel1],
          outputs: %w[SUBSCRIBE test:channel1]
        },
        {
          pattern: "multi keys",
          inputs: %w[SUBSCRIBE channel1 channel2 channel3],
          outputs: %w[SUBSCRIBE test:channel1 test:channel2 test:channel3]
        }
      ],
      "UNSUBSCRIBE" => [
        {
          pattern: "basic",
          inputs: %w[UNSUBSCRIBE channel1],
          outputs: %w[UNSUBSCRIBE test:channel1]
        },
        {
          pattern: "multi keys",
          inputs: %w[UNSUBSCRIBE channel1 channel2 channel3],
          outputs: %w[UNSUBSCRIBE test:channel1 test:channel2 test:channel3]
        }
      ],
      "PSUBSCRIBE" => [
        {
          pattern: "basic",
          inputs: %w[PSUBSCRIBE pattern*],
          outputs: %w[PSUBSCRIBE test:pattern*]
        },
        {
          pattern: "multi patterns",
          inputs: %w[PSUBSCRIBE pattern* test*],
          outputs: %w[PSUBSCRIBE test:pattern* test:test*]
        }
      ],
      "PUNSUBSCRIBE" => [
        {
          pattern: "basic",
          inputs: %w[PUNSUBSCRIBE pattern*],
          outputs: %w[PUNSUBSCRIBE test:pattern*]
        },
        {
          pattern: "multi patterns",
          inputs: %w[PUNSUBSCRIBE pattern* test*],
          outputs: %w[PUNSUBSCRIBE test:pattern* test:test*]
        }
      ],
      "PUBLISH" => [
        {
          pattern: "basic",
          inputs: %w[PUBLISH channel message],
          outputs: %w[PUBLISH test:channel message]
        }
      ],
      "PUBSUB" => [
        {
          pattern: "CHANNELS with pattern",
          inputs: %w[PUBSUB CHANNELS pattern*],
          outputs: %w[PUBSUB CHANNELS test:pattern*]
        },
        {
          pattern: "NUMSUB with multi channels",
          inputs: %w[PUBSUB NUMSUB channel1 channel2 channel3],
          outputs: %w[PUBSUB NUMSUB test:channel1 test:channel2 test:channel3]
        },
        {
          pattern: "NUMPAT",
          inputs: %w[PUBSUB NUMPAT],
          outputs: %w[PUBSUB NUMPAT]
        },
        {
          pattern: "SHARDNUMSUB with multi channels",
          inputs: %w[PUBSUB SHARDNUMSUB shard1 shard2],
          outputs: %w[PUBSUB SHARDNUMSUB test:shard1 test:shard2]
        }
      ],
      "XREAD" => [
        {
          pattern: "with COUNT and multi streams",
          inputs: %w[XREAD COUNT 10 STREAMS stream1 stream2 0-0 0-0],
          outputs: %w[XREAD COUNT 10 STREAMS test:stream1 test:stream2 0-0 0-0]
        }
      ],
      "XREADGROUP" => [
        {
          pattern: "basic with multi streams",
          inputs: %w[XREADGROUP GROUP mygroup consumer1 STREAMS stream1 stream2 > >],
          outputs: %w[XREADGROUP GROUP mygroup consumer1 STREAMS test:stream1 test:stream2 > >]
        },
        {
          pattern: "with COUNT and BLOCK",
          inputs: %w[XREADGROUP GROUP mygroup consumer1 COUNT 10 BLOCK 1000 STREAMS stream1 >],
          outputs: %w[XREADGROUP GROUP mygroup consumer1 COUNT 10 BLOCK 1000 STREAMS test:stream1 >]
        }
      ],
      "GEORADIUS" => [
        {
          pattern: "basic",
          inputs: %w[GEORADIUS key 15 37 200 km],
          outputs: %w[GEORADIUS test:key 15 37 200 km]
        },
        {
          pattern: "with STORE",
          inputs: %w[GEORADIUS key 15 37 200 km STORE dest],
          outputs: %w[GEORADIUS test:key 15 37 200 km STORE test:dest]
        }
      ],
      "GEORADIUSBYMEMBER" => [
        {
          pattern: "basic",
          inputs: %w[GEORADIUSBYMEMBER key member 100 km],
          outputs: %w[GEORADIUSBYMEMBER test:key member 100 km]
        },
        {
          pattern: "with STORE",
          inputs: %w[GEORADIUSBYMEMBER key member 100 km STORE dest],
          outputs: %w[GEORADIUSBYMEMBER test:key member 100 km STORE test:dest]
        },
        {
          pattern: "with STOREDIST",
          inputs: %w[GEORADIUSBYMEMBER key member 100 km STOREDIST dest],
          outputs: %w[GEORADIUSBYMEMBER test:key member 100 km STOREDIST test:dest]
        }
      ],
      "MIGRATE" => [
        {
          pattern: "single key",
          inputs: %w[MIGRATE 127.0.0.1 6379 key 0 1000],
          outputs: %w[MIGRATE 127.0.0.1 6379 test:key 0 1000]
        },
        {
          pattern: "with KEYS option",
          inputs: ["MIGRATE", "127.0.0.1", "6379", "", "0", "1000", "KEYS", "key1", "key2", "key3"],
          outputs: ["MIGRATE", "127.0.0.1", "6379", "", "0", "1000", "KEYS", "test:key1", "test:key2", "test:key3"]
        }
      ],
      "HSCAN" => [
        {
          pattern: "basic",
          inputs: %w[HSCAN hash 0],
          outputs: %w[HSCAN test:hash 0]
        },
        {
          pattern: "with MATCH",
          inputs: %w[HSCAN hash 0 MATCH field*],
          outputs: %w[HSCAN test:hash 0 MATCH field*]
        }
      ],
      "SSCAN" => [
        {
          pattern: "with MATCH and COUNT",
          inputs: %w[SSCAN set 0 MATCH member* COUNT 10],
          outputs: %w[SSCAN test:set 0 MATCH member* COUNT 10]
        }
      ],
      "ZSCAN" => [
        {
          pattern: "with MATCH",
          inputs: %w[ZSCAN zset 0 MATCH member*],
          outputs: %w[ZSCAN test:zset 0 MATCH member*]
        }
      ],
      "SORT" => [
        {
          pattern: "with BY, GET, STORE",
          inputs: %w[SORT list BY weight_* GET object_* STORE result],
          outputs: %w[SORT test:list BY test:weight_* GET test:object_* STORE test:result]
        },
        {
          pattern: "with GET # (no transformation)",
          inputs: %w[SORT list GET #],
          outputs: %w[SORT test:list GET #]
        }
      ],
      "SORT_RO" => [
        {
          pattern: "with patterns",
          inputs: %w[SORT_RO list BY weight_* GET object_*],
          outputs: %w[SORT_RO test:list BY test:weight_* GET test:object_*]
        }
      ],

      # Commands with patterns not covered by auto_spec
      # These test multiple key-value pairs in repeating blocks
      "MSET" => [
        {
          pattern: "multiple key-value pairs",
          inputs: %w[MSET key1 Hello key2 World],
          outputs: %w[MSET test:key1 Hello test:key2 World]
        }
      ],
      "MSETNX" => [
        {
          pattern: "multiple key-value pairs",
          inputs: %w[MSETNX key1 Hello key2 there],
          outputs: %w[MSETNX test:key1 Hello test:key2 there]
        }
      ]
    }

    testcases.each do |cmd_name, cases|
      context cmd_name do
        cases.each do |t|
          it "#{t[:pattern]}: [#{t[:inputs].map(&:to_s).join(" ")}] -> [#{t[:outputs].map(&:to_s).join(" ")}]" do
            expect(builder.generate(t[:inputs])).to eq(t[:outputs])
          end
        end
      end
    end
  end
end
