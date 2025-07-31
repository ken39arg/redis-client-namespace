# frozen_string_literal: true

class RedisClient
  class Namespace
    module CommandBuilder
      # Namespace transformation strategies
      STRATEGIES = {
        # Basic common strategies
        none: ->(cmd, &block) {}, # No transformation
        all: ->(cmd, &block) { cmd.drop(1).each_with_index { |key, i| cmd[i + 1] = block.call(key) } },
        first: ->(cmd, &block) { cmd[1] = block.call(cmd[1]) if cmd[1] },
        second: ->(cmd, &block) { cmd[2] = block.call(cmd[2]) if cmd[2] },
        first_two: lambda { |cmd, &block|
          cmd[1] = block.call(cmd[1]) if cmd[1]
          cmd[2] = block.call(cmd[2]) if cmd[2]
        },
        exclude_first: ->(cmd, &block) { cmd.drop(2).each_with_index { |key, i| cmd[i + 2] = block.call(key) } },
        exclude_last: lambda { |cmd, &block|
          return if cmd.size < 3

          (1...(cmd.size - 1)).each { |i| cmd[i] = block.call(cmd[i]) }
        },
        alternate: lambda { |cmd, &block|
          cmd.drop(1).each_with_index do |item, i|
            cmd[i + 1] = block.call(item) if i.even?
          end
        },

        # Custom strategies used by multiple commands
        eval_style: lambda { |cmd, &block|
          return if cmd.size < 3

          numkeys = cmd[2].to_i
          actual_keys = [numkeys, cmd.size - 3].min
          actual_keys.times { |i| cmd[3 + i] = block.call(cmd[3 + i]) if cmd[3 + i] }
        },

        # Single-command specific strategies
        sort: lambda { |cmd, &block|
          cmd[1] = block.call(cmd[1]) if cmd[1]
          # Handle BY, GET, STORE options
          cmd.each_with_index do |arg, i|
            next if i.zero?

            case arg.to_s.upcase
            when "BY", "STORE"
              cmd[i + 1] = block.call(cmd[i + 1]) if cmd[i + 1]
            when "GET"
              # GET can be "#" or a pattern
              cmd[i + 1] = block.call(cmd[i + 1]) if cmd[i + 1] && cmd[i + 1] != "#"
            end
          end
        },
        georadius_style: lambda { |cmd, &block|
          cmd[1] = block.call(cmd[1]) if cmd[1]
          # Handle STORE, STOREDIST options
          cmd.each_with_index do |arg, i|
            if (arg.to_s.casecmp("STORE").zero? || arg.to_s.casecmp("STOREDIST").zero?) && cmd[i + 1]
              cmd[i + 1] = block.call(cmd[i + 1])
            end
          end
        },
        xread_style: lambda { |cmd, &block|
          # Find STREAMS keyword
          streams_idx = cmd.index { |arg| arg.to_s.casecmp("STREAMS").zero? }
          return unless streams_idx

          # Transform keys after STREAMS
          num_keys = (cmd.size - streams_idx - 1) / 2
          num_keys.times do |i|
            key_idx = streams_idx + 1 + i
            cmd[key_idx] = block.call(cmd[key_idx]) if cmd[key_idx]
          end
        },
        migrate: lambda { |cmd, &block|
          # MIGRATE host port key destination-db timeout [options]
          # MIGRATE host port "" destination-db timeout [COPY | REPLACE] KEYS key [key ...]
          if cmd[3] && cmd[3] != ""
            # Single key format
            cmd[3] = block.call(cmd[3])
          elsif (keys_idx = cmd.index { |arg| arg.to_s.casecmp("KEYS").zero? })
            # Multiple keys format - transform keys after KEYS keyword
            ((keys_idx + 1)...cmd.size).each do |i|
              cmd[i] = block.call(cmd[i]) if cmd[i]
            end
          end
        },
        zinterstore_style: lambda { |cmd, &block|
          # ZINTERSTORE destination numkeys key [key ...]
          return if cmd.size < 3

          cmd[1] = block.call(cmd[1]) if cmd[1] # destination

          numkeys = cmd[2].to_i
          actual_keys = [numkeys, cmd.size - 3].min
          actual_keys.times do |i|
            key_idx = 3 + i
            cmd[key_idx] = block.call(cmd[key_idx]) if cmd[key_idx]
          end
        },
        blmpop_style: lambda { |cmd, &block|
          # BLMPOP timeout numkeys key [key ...] <LEFT | RIGHT> [COUNT count]
          return if cmd.size < 4

          numkeys = cmd[2].to_i
          actual_keys = [numkeys, cmd.size - 3].min
          actual_keys.times do |i|
            key_idx = 3 + i
            cmd[key_idx] = block.call(cmd[key_idx]) if cmd[key_idx]
          end
        },
        lmpop_style: lambda { |cmd, &block|
          # LMPOP numkeys key [key ...] <LEFT | RIGHT> [COUNT count]
          return if cmd.size < 3

          numkeys = cmd[1].to_i
          actual_keys = [numkeys, cmd.size - 2].min
          actual_keys.times do |i|
            key_idx = 2 + i
            cmd[key_idx] = block.call(cmd[key_idx]) if cmd[key_idx]
          end
        },
        scan_cursor_style: lambda { |cmd, &block|
          # SCAN cursor [MATCH pattern] [COUNT count] [TYPE type]
          # Only transform MATCH pattern if present and command is SCAN
          if cmd[0].to_s.casecmp("SCAN").zero? && (match_idx = cmd.index do |arg|
            arg.to_s.casecmp("MATCH").zero?
          end) && cmd[match_idx + 1]
            cmd[match_idx + 1] = block.call(cmd[match_idx + 1])
          end
        },
        pubsub_style: lambda { |cmd, &block|
          # PUBSUB CHANNELS [pattern]
          # PUBSUB NUMSUB [channel [channel ...]]
          # PUBSUB SHARDCHANNELS [pattern]
          # PUBSUB SHARDNUMSUB [shardchannel [shardchannel ...]]
          return if cmd.size < 2

          subcommand = cmd[1].to_s.upcase
          case subcommand
          when "CHANNELS", "SHARDCHANNELS"
            # Transform pattern if present
            cmd[2] = block.call(cmd[2]) if cmd[2]
          when "NUMSUB", "SHARDNUMSUB"
            # Transform all channels starting from index 2
            (2...cmd.size).each do |i|
              cmd[i] = block.call(cmd[i]) if cmd[i]
            end
            # NUMPAT has no channels to transform
          end
        },
        scan_style: lambda { |cmd, &block|
          # HSCAN/SSCAN/ZSCAN key cursor [MATCH pattern] [COUNT count]
          # First argument is the key, don't transform MATCH pattern for HSCAN/SSCAN/ZSCAN
          cmd[1] = block.call(cmd[1]) if cmd[1]
        },
        memory_usage: lambda { |cmd, &block|
          # MEMORY USAGE key [SAMPLES samples]
          cmd[2] = block.call(cmd[2]) if cmd.size >= 3 && cmd[1].to_s.casecmp("USAGE").zero? && cmd[2]
        }
      }.freeze

      # Command to strategy mapping (inspired by redis-namespace)
      COMMANDS = {
        # Generic
        "DEL" => :all,
        "EXISTS" => :all,
        "EXPIRE" => :first,
        "EXPIREAT" => :first,
        "KEYS" => :first,
        "MOVE" => :first,
        "PERSIST" => :first,
        "PEXPIRE" => :first,
        "PEXPIREAT" => :first,
        "PTTL" => :first,
        "RANDOMKEY" => :none,
        "RENAME" => :first_two,
        "RENAMENX" => :first_two,
        "RESTORE" => :first,
        "TTL" => :first,
        "TYPE" => :first,
        "UNLINK" => :all,
        "SCAN" => :scan_cursor_style,
        "DUMP" => :first,
        "COPY" => :first_two,
        "MIGRATE" => :migrate,
        "SORT" => :sort,
        "SORT_RO" => :sort,
        "TOUCH" => :all,
        "WAIT" => :none,
        "WAITAOF" => :none,
        "OBJECT" => :second,
        "RESTORE-ASKING" => :first,
        "EXPIRETIME" => :first,
        "PEXPIRETIME" => :first,

        # Bitmap
        "BITCOUNT" => :first,
        "BITOP" => :exclude_first,
        "BITPOS" => :first,
        "BITFIELD" => :first,
        "BITFIELD_RO" => :first,
        "GETBIT" => :first,
        "SETBIT" => :first,

        # String
        "APPEND" => :first,
        "DECR" => :first,
        "DECRBY" => :first,
        "GET" => :first,
        "GETRANGE" => :first,
        "GETSET" => :first,
        "INCR" => :first,
        "INCRBY" => :first,
        "INCRBYFLOAT" => :first,
        "MGET" => :all,
        "MSET" => :alternate,
        "MSETNX" => :alternate,
        "PSETEX" => :first,
        "SET" => :first,
        "SETEX" => :first,
        "SETNX" => :first,
        "SETRANGE" => :first,
        "STRLEN" => :first,
        "GETDEL" => :first,
        "GETEX" => :first,
        "LCS" => :first_two,
        "SUBSTR" => :first,

        # List
        "BLPOP" => :exclude_last,
        "BRPOP" => :exclude_last,
        "BRPOPLPUSH" => :first_two,
        "LINDEX" => :first,
        "LINSERT" => :first,
        "LLEN" => :first,
        "LPOP" => :first,
        "LPUSH" => :first,
        "LPUSHX" => :first,
        "LRANGE" => :first,
        "LREM" => :first,
        "LSET" => :first,
        "LTRIM" => :first,
        "RPOP" => :first,
        "RPOPLPUSH" => :first_two,
        "RPUSH" => :first,
        "RPUSHX" => :first,
        "LMOVE" => :first_two,
        "BLMOVE" => :first_two,
        "LMPOP" => :lmpop_style,
        "BLMPOP" => :blmpop_style,
        "LPOS" => :first,

        # Set
        "SADD" => :first,
        "SCARD" => :first,
        "SDIFF" => :all,
        "SDIFFSTORE" => :all,
        "SINTER" => :all,
        "SINTERSTORE" => :all,
        "SISMEMBER" => :first,
        "SMEMBERS" => :first,
        "SMISMEMBER" => :first,
        "SMOVE" => :first_two,
        "SPOP" => :first,
        "SRANDMEMBER" => :first,
        "SREM" => :first,
        "SUNION" => :all,
        "SUNIONSTORE" => :all,
        "SSCAN" => :scan_style,
        "SINTERCARD" => :lmpop_style,

        # Sorted-set
        "BZPOPMIN" => :exclude_last,
        "BZPOPMAX" => :exclude_last,
        "ZADD" => :first,
        "ZCARD" => :first,
        "ZCOUNT" => :first,
        "ZINCRBY" => :first,
        "ZINTERSTORE" => :zinterstore_style,
        "ZLEXCOUNT" => :first,
        "ZPOPMAX" => :first,
        "ZPOPMIN" => :first,
        "ZRANGE" => :first,
        "ZRANGEBYLEX" => :first,
        "ZREVRANGEBYLEX" => :first,
        "ZRANGEBYSCORE" => :first,
        "ZRANK" => :first,
        "ZREM" => :first,
        "ZREMRANGEBYLEX" => :first,
        "ZREMRANGEBYRANK" => :first,
        "ZREMRANGEBYSCORE" => :first,
        "ZREVRANGE" => :first,
        "ZREVRANGEBYSCORE" => :first,
        "ZREVRANK" => :first,
        "ZSCORE" => :first,
        "ZUNIONSTORE" => :zinterstore_style,
        "ZMSCORE" => :first,
        "ZSCAN" => :scan_style,
        "ZDIFF" => :lmpop_style,
        "ZDIFFSTORE" => :zinterstore_style,
        "ZINTER" => :lmpop_style,
        "ZUNION" => :lmpop_style,
        "ZRANDMEMBER" => :first,
        "BZMPOP" => :blmpop_style,
        "ZMPOP" => :lmpop_style,
        "ZINTERCARD" => :lmpop_style,
        "ZRANGESTORE" => :first_two,

        # Hash
        "HDEL" => :first,
        "HEXISTS" => :first,
        "HGET" => :first,
        "HGETALL" => :first,
        "HINCRBY" => :first,
        "HINCRBYFLOAT" => :first,
        "HKEYS" => :first,
        "HLEN" => :first,
        "HMGET" => :first,
        "HMSET" => :first,
        "HSET" => :first,
        "HSETNX" => :first,
        "HSTRLEN" => :first,
        "HVALS" => :first,
        "HSCAN" => :scan_style,
        "HRANDFIELD" => :first,
        "HEXPIRE" => :first,
        "HEXPIREAT" => :first,
        "HEXPIRETIME" => :first,
        "HPERSIST" => :first,
        "HPEXPIRE" => :first,
        "HPEXPIREAT" => :first,
        "HPEXPIRETIME" => :first,
        "HTTL" => :first,
        "HPTTL" => :first,
        "HGETF" => :first,
        "HSETF" => :first,

        # Hyperloglog
        "PFADD" => :first,
        "PFCOUNT" => :all,
        "PFMERGE" => :all,
        "PFDEBUG" => :second,

        # Geo
        "GEOADD" => :first,
        "GEODIST" => :first,
        "GEOHASH" => :first,
        "GEOPOS" => :first,
        "GEORADIUS" => :georadius_style,
        "GEORADIUSBYMEMBER" => :georadius_style,
        "GEOSEARCH" => :first,
        "GEOSEARCHSTORE" => :first_two,
        "GEORADIUS_RO" => :georadius_style,
        "GEORADIUSBYMEMBER_RO" => :georadius_style,

        # Stream
        "XADD" => :first,
        "XRANGE" => :first,
        "XREVRANGE" => :first,
        "XLEN" => :first,
        "XREAD" => :xread_style,
        "XREADGROUP" => :xread_style,
        "XGROUP" => :second,
        "XACK" => :first,
        "XCLAIM" => :first,
        "XDEL" => :first,
        "XTRIM" => :first,
        "XPENDING" => :first,
        "XINFO" => :second,
        "XAUTOCLAIM" => :first,
        "XSETID" => :first,

        # Pubsub
        "PSUBSCRIBE" => :all,
        "PUBLISH" => :first,
        "PUNSUBSCRIBE" => :all,
        "SUBSCRIBE" => :all,
        "UNSUBSCRIBE" => :all,
        "PUBSUB" => :pubsub_style,
        "SPUBLISH" => :none,
        "SSUBSCRIBE" => :none,
        "SUNSUBSCRIBE" => :none,

        # Transactions
        "DISCARD" => :none,
        "EXEC" => :none,
        "MULTI" => :none,
        "UNWATCH" => :none,
        "WATCH" => :all,

        # Scripting
        "EVAL" => :eval_style,
        "EVALSHA" => :eval_style,
        "SCRIPT" => :none,
        "EVAL_RO" => :eval_style,
        "EVALSHA_RO" => :eval_style,
        "FCALL" => :eval_style,
        "FCALL_RO" => :eval_style,
        "FUNCTION" => :none,

        # Connection
        "AUTH" => :none,
        "ECHO" => :none,
        "PING" => :none,
        "QUIT" => :none,
        "SELECT" => :none,
        "SWAPDB" => :none,
        "RESET" => :none,

        # Server
        "BGREWRITEAOF" => :none,
        "BGSAVE" => :none,
        "CLIENT" => :none,
        "COMMAND" => :none,
        "CONFIG" => :none,
        "DBSIZE" => :none,
        "DEBUG" => :none,
        "FLUSHALL" => :none,
        "FLUSHDB" => :none,
        "INFO" => :none,
        "LASTSAVE" => :none,
        "MEMORY" => :memory_usage,
        "MONITOR" => :none,
        "SAVE" => :none,
        "SHUTDOWN" => :none,
        "SLAVEOF" => :none,
        "SLOWLOG" => :none,
        "SYNC" => :none,
        "TIME" => :none,
        "LATENCY" => :none,
        "LOLWUT" => :none,
        "ACL" => :none,
        "MODULE" => :none,
        "CLUSTER" => :none,
        "HELLO" => :none,
        "FAILOVER" => :none,
        "REPLICAOF" => :none,
        "PSYNC" => :none

      }.freeze

      def generate(args, kwargs = nil)
        namespaced_command(@parent_command_builder.generate(args, kwargs), namespace: @namespace, separator: @separator)
      end

      def namespaced_command(command, namespace: nil, separator: ":")
        return command if namespace.nil? || namespace.empty? || command.size < 2

        cmd_name = command[0].to_s.upcase
        strategy = COMMANDS[cmd_name]

        # Raise error for unknown commands to maintain compatibility with redis-namespace
        unless strategy
          raise(::RedisClient::Namespace::Error,
                "RedisClient::Namespace does not know how to handle '#{cmd_name}'.")
        end

        STRATEGIES[strategy].call(command) { |key| "#{namespace}#{separator}#{key}" }

        command
      end
    end
  end
end
