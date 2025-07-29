# Benchmarks

This directory contains performance benchmarks comparing `redis-client-namespace` with the traditional `redis-namespace` gem.

## Running Benchmarks

### Prerequisites

First, install the benchmark dependencies:

```bash
bundle install --with benchmark
```

### Redis Namespace Comparison

To run the benchmark comparing `redis-namespace` vs `redis-client-namespace`:

```bash
# Using default Redis (localhost:6379)
ruby benchmark/redis_namespace_comparison.rb

# Using custom Redis server
REDIS_HOST=localhost REDIS_PORT=16379 ruby benchmark/redis_namespace_comparison.rb
```

This benchmark tests various Redis operations:
- Single key operations (SET, GET)
- Multiple key operations (MGET)
- List operations (LPUSH, LRANGE)
- Hash operations (HSET, HGETALL)
- Set operations (SADD, SMEMBERS)
- Pattern matching (KEYS)
- Complex operations (ZRANGE)
- Transactions (MULTI/EXEC)

## Expected Results

The `redis-client-namespace` gem is designed to have minimal overhead compared to `redis-namespace`. The benchmarks help verify that the performance characteristics are comparable or better across different types of Redis operations.

## Adding New Benchmarks

To add new benchmarks:
1. Create a new Ruby file in this directory
2. Use `benchmark-ips` for consistent measurement
3. Include warm-up phases to ensure fair comparison
4. Test a variety of Redis operations relevant to your use case