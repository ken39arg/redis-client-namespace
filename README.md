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

### Basic Usage

```ruby
require 'redis-client-namespace'

# Create a namespaced command builder
namespace = RedisClient::Namespace.new("myapp")

# Use with redis-client
client = RedisClient.new(command_builder: namespace)

# All commands will be automatically namespaced
client.set("user:123", "john")           # Actually sets "myapp:user:123"
client.get("user:123")                   # Actually gets "myapp:user:123"
client.del("user:123", "user:456")       # Actually deletes "myapp:user:123", "myapp:user:456"
```

### Custom Separator

```ruby
# Use a custom separator
namespace = RedisClient::Namespace.new("myapp", separator: "-")
client = RedisClient.new(command_builder: namespace)

client.set("user:123", "john")           # Actually sets "myapp-user:123"
```

### Nested Namespaces

```ruby
# Create nested namespaces
parent = RedisClient::Namespace.new("myapp")
child = RedisClient::Namespace.new("jobs", parent_command_builder: parent)

client = RedisClient.new(command_builder: child)
client.set("queue", "important")         # Actually sets "jobs:myapp:queue"
```

### Sidekiq Integration

This gem is particularly useful for Sidekiq applications that need namespace isolation:

```ruby
# In your Sidekiq configuration
require 'redis-client-namespace'

namespace = RedisClient::Namespace.new("sidekiq_production")
Sidekiq.configure_server do |config|
  config.redis = { command_builder: namespace }
end

Sidekiq.configure_client do |config|
  config.redis = { command_builder: namespace }
end
```

## Supported Redis Commands

RedisClient::Namespace supports all Redis commands with intelligent key transformation:

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

## Advanced Features

### Pattern Matching

For commands like `SCAN` and `KEYS`, the namespace is automatically applied to patterns:

```ruby
namespace = RedisClient::Namespace.new("myapp")
client = RedisClient.new(command_builder: namespace)

# This will scan for "myapp:user:*" pattern
client.scan(0, match: "user:*")
```

### Complex Commands

The gem handles complex commands with multiple keys intelligently:

```ruby
# SORT command with BY and GET options
client.sort("list", by: "weight_*", get: "object_*", store: "result")
# Becomes: SORT myapp:list BY myapp:weight_* GET myapp:object_* STORE myapp:result

# Lua scripts with proper key handling
client.eval("return redis.call('get', KEYS[1])", 1, "mykey")
# The key "mykey" becomes "myapp:mykey"
```

## Configuration Options

- `namespace`: The namespace prefix to use (required)
- `separator`: The separator between namespace and key (default: `":"`)
- `parent_command_builder`: Parent command builder for nested namespaces (default: `RedisClient::CommandBuilder`)

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

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

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

The gem includes comprehensive tests covering all Redis commands. Our test suite uses the official [Redis commands.json](https://github.com/redis/docs/blob/main/data/commands.json) specification to ensure complete coverage of all Redis commands and their key transformation strategies:

- **Automated command coverage**: Tests are generated from Redis's official command specification
- **Manual edge case testing**: Complex commands like `SORT`, `EVAL`, and `MIGRATE` have dedicated test suites
- **Full Redis compatibility**: Ensures all current and future Redis commands work correctly

```bash
bundle exec rspec
```

This approach guarantees that RedisClient::Namespace stays up-to-date with Redis command changes and maintains 100% command compatibility.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ken39arg/redis-client-namespace. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/ken39arg/redis-client-namespace/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the RedisClient::Namespace project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/ken39arg/redis-client-namespace/blob/main/CODE_OF_CONDUCT.md).