## [Unreleased]

### Added
- Added `RedisClient::Namespace::Middleware` for full namespace support including result processing
- Added automatic removal of namespace prefixes from command results (KEYS, SCAN, BLPOP, BRPOP)
- Middleware approach allows proper handling of both command transformation and result trimming

### Changed
- **BREAKING**: Middleware approach is now the recommended way to use RedisClient::Namespace
- Updated README to focus on middleware usage with comprehensive examples
- Updated Sidekiq integration examples to use middleware approach

### Deprecated
- Using `RedisClient::Namespace` as a command_builder is now deprecated
- The command_builder approach cannot process results to remove namespace prefixes
- Users should migrate to the middleware approach for complete namespace functionality

### Technical Changes
- Refactored `namespaced_command` method as a static method in `CommandBuilder` module
- Added `trimed_result` method for processing command results
- Enhanced middleware implementation to handle both single commands and pipelined operations

## [0.1.1] - 2025-07-29

- Add `RedisClient::Namespace.command_builder` class method for conditional namespacing based on environment variables

## [0.1.0] - 2025-07-26

- Initial release
