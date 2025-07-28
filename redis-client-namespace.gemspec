# frozen_string_literal: true

require_relative "lib/redis_client/namespace/version"

Gem::Specification.new do |spec|
  spec.name = "redis-client-namespace"
  spec.version = RedisClient::Namespace::VERSION
  spec.authors = ["Kensaku Araga"]
  spec.email = ["k_araga@ivry.jp"]

  spec.summary = "Namespace support for redis-client"
  spec.description = "Adds transparent namespace prefixing to Redis keys " \
                     "for multi-tenant applications using redis-client."
  spec.homepage = "https://github.com/ken39arg/redis-client-namespace"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ken39arg/redis-client-namespace"
  spec.metadata["changelog_uri"] = "https://github.com/ken39arg/redis-client-namespace/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "redis-client", ">= 0.22.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
