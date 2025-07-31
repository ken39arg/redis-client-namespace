# RedisClient::Namespace

A Redis namespace extension for [redis-client](https://github.com/redis-rb/redis-client) gem that automatically prefixes Redis keys with a namespace, enabling multi-tenancy and key isolation in Redis applications.

This gem works by wrapping `RedisClient::CommandBuilder` and intercepting Redis commands to transparently add namespace prefixes to keys before they are sent to Redis.

## Motivation

This gem was created to provide namespace support for [Sidekiq](https://github.com/sidekiq/sidekiq) applications using the `redis-client` gem. As Sidekiq migrates from the `redis` gem to `redis-client`, there was a need for a namespace solution that works seamlessly with the new client architecture while maintaining compatibility with existing namespace-based deployments.

## Features

- **Transparent key namespacing**: Automatically prefixes Redis keys with a configurable namespace
- **Comprehensive command support**: Supports all Redis commands with intelligent key detection
- **Customizable separator**: Configure the namespace separator (default: `:`)
- **Nested namespaces**: Support for nested command builders with multiple namespace levels
- **Zero configuration**: Works out of the box with sensible defaults
- **High performance**: Minimal overhead with efficient command transformation
- **Thread-safe**: Safe for use in multi-threaded applications

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'redis-client-namespace'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install redis-client-namespace
```

## Usage

### Basic Usage with Middleware (Recommended)

RedisClient::Namespace is implemented as a [RedisClient middleware](https://github.com/redis-rb/redis-client#instrumentation-and-middlewares) that transparently handles both command transformation and result processing:

```ruby
require 'redis-client-namespace'

# Configure RedisClient with the namespace middleware
client = RedisClient.config(
  middlewares: [RedisClient::Namespace::Middleware],
  custom: { namespace: "myapp", separator: ":" }
).new_client

# All commands will be automatically namespaced
client.call("SET", "user:123", "john")   # Actually sets "myapp:user:123"
client.call("GET", "user:123")           # Actually gets "myapp:user:123"

# Commands that return keys will have the namespace automatically removed
client.call("KEYS", "*")                  # Returns ["user:123"] instead of ["myapp:user:123"]
client.call("SCAN", 0, "MATCH", "user:*") # Returns keys without namespace prefix
```

### Custom Separator

```ruby
# Use a custom separator
client = RedisClient.config(
  middlewares: [RedisClient::Namespace::Middleware],
  custom: { namespace: "myapp", separator: "-" }
).new_client

client.call("SET", "user:123", "john")   # Actually sets "myapp-user:123"
```

### with Redis (`redis-rb`)

This gem also works with the [redis](https://github.com/redis/redis-rb) gem through its middleware support:

```ruby
require 'redis'
require 'redis-client-namespace'

# Use with redis-rb via middleware
redis = Redis.new(
  host: 'localhost', 
  port: 6379,
  middlewares: [RedisClient::Namespace::Middleware],
  custom: { namespace: "myapp", separator: ":" }
)

# All commands will be automatically namespaced
redis.set("user:123", "john")            # Actually sets "myapp:user:123"
redis.get("user:123")                    # Actually gets "myapp:user:123"
redis.del("user:123", "user:456")        # Actually deletes "myapp:user:123", "myapp:user:456"

# Works with all Redis commands
redis.lpush("queue", ["job1", "job2"])   # Actually pushes to "myapp:queue"
redis.hset("config", "timeout", "30")    # Actually sets in "myapp:config"
redis.sadd("tags", "ruby", "rails")      # Actually adds to "myapp:tags"

# Pattern matching with automatic namespace removal
redis.keys("user:*")                     # Returns ["user:123"] instead of ["myapp:user:123"]
```

### Sidekiq Integration

This gem is particularly useful for Sidekiq applications that need namespace isolation:

```ruby
# In your Sidekiq configuration
require 'redis-client-namespace'

Sidekiq.configure_server do |config|
  config.redis = {
    url: 'redis://redis:6379/1',
    middlewares: [RedisClient::Namespace::Middleware],
    custom: { namespace: "sidekiq_production", separator: ":" }
  }
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: 'redis://redis:6379/1',
    middlewares: [RedisClient::Namespace::Middleware],
    custom: { namespace: "sidekiq_production", separator: ":" }
  }
end
```

## Supported Redis Commands

RedisClient::Namespace supports the vast majority of Redis commands with intelligent key transformation:

- **String commands**: `GET`, `SET`, `MGET`, `MSET`, etc.
- **List commands**: `LPUSH`, `RPOP`, `LRANGE`, etc.
- **Set commands**: `SADD`, `SREM`, `SINTER`, etc.
- **Sorted Set commands**: `ZADD`, `ZCOUNT`, `ZRANGE`, etc.
- **Hash commands**: `HGET`, `HSET`, `HDEL`, etc.
- **Stream commands**: `XADD`, `XREAD`, `XGROUP`, etc.
- **Pub/Sub commands**: `PUBLISH`, `SUBSCRIBE`, etc.
- **Scripting commands**: `EVAL`, `EVALSHA` with proper key handling
- **Transaction commands**: `WATCH`, `MULTI`, `EXEC`
- **And many more...**

The gem automatically detects which arguments are keys and applies the namespace prefix accordingly.

### Limitations

#### Pub/Sub Events

When using the Middleware approach, Pub/Sub subscribe events (via `pubsub.next_event`) are not automatically processed to remove namespace prefixes from channel names. This is because the middleware doesn't have access to intercept the `next_event` method.

If you're using Pub/Sub with the middleware approach, you'll need to manually handle namespace removal:

```ruby
# With middleware approach
pubsub = client.pubsub
pubsub.call("SUBSCRIBE", "channel1")  # Subscribes to "myapp:channel1"

# You need to manually remove the namespace prefix from received events
event = pubsub.next_event
if event && event[0] == "message"
  channel = event[1].delete_prefix("myapp:")  # Remove namespace manually
  message = event[2]
end
```


## Advanced Features

### Pattern Matching

For commands like `SCAN` and `KEYS`, the namespace is automatically applied to patterns:

```ruby
client = RedisClient.config(
  middlewares: [RedisClient::Namespace::Middleware],
  custom: { namespace: "myapp", separator: ":" }
).new_client

# This will scan for "myapp:user:*" pattern
client.call("SCAN", 0, "MATCH", "user:*")
# Returns keys without the namespace prefix for easier handling
```

### Complex Commands

The gem handles complex commands with multiple keys intelligently:

```ruby
# SORT command with BY and GET options
client.call("SORT", "list", "BY", "weight_*", "GET", "object_*", "STORE", "result")
# Becomes: SORT myapp:list BY myapp:weight_* GET myapp:object_* STORE myapp:result

# Lua scripts with proper key handling
client.call("EVAL", "return redis.call('get', KEYS[1])", 1, "mykey")
# The key "mykey" becomes "myapp:mykey"
```

## Configuration Options

When using the middleware approach, configure via the `custom` option:

- `namespace`: The namespace prefix to use (required)
- `separator`: The separator between namespace and key (default: `":"`)

## Thread Safety

RedisClient::Namespace is **thread-safe** and can be used in multi-threaded applications without additional synchronization. The implementation:

- Uses immutable instance variables (`@namespace`, `@separator`, `@parent_command_builder`) that are set once during initialization
- Never modifies shared state during command processing
- Creates new command arrays for each operation without mutating the original
- Uses frozen constants for strategy and command mappings

Each `generate` call is completely independent, making it safe to use the same namespace instance across multiple threads.

## Performance

The gem adds minimal overhead to Redis operations. Command transformation is performed efficiently with optimized strategies for different command patterns.

## Development

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`.

### Local Testing with Redis

For local development and testing, you can use Docker Compose to run Redis:

```bash
# Start Redis on port 16379
docker compose up -d

# Run tests against the local Redis instance
REDIS_PORT=16379 bundle exec rake

# Stop Redis when done
docker compose down
```

## Testing

The gem includes comprehensive tests covering Redis commands. Our test suite uses the official [Redis commands.json](https://github.com/redis/docs/blob/main/data/commands.json) specification to ensure broad coverage of Redis commands and their key transformation strategies:

- **Automated command coverage**: Tests are generated from Redis's official command specification
- **Manual edge case testing**: Complex commands like `SORT`, `EVAL`, and `MIGRATE` have dedicated test suites
- **Wide Redis compatibility**: Supports the vast majority of Redis commands with proper key handling

```bash
bundle exec rspec
```

This approach helps RedisClient::Namespace stay compatible with Redis command changes and maintain compatibility with most Redis operations.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ken39arg/redis-client-namespace. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/ken39arg/redis-client-namespace/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the RedisClient::Namespace project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/ken39arg/redis-client-namespace/blob/main/CODE_OF_CONDUCT.md).
