# frozen_string_literal: true

require "json"

def make_test_case(namespace, cmd_name, arguments, multi_size: 1, non_optional: false)
  inputs = cmd_name.split
  outputs = inputs.dup
  arguments.each do |arg|
    next if non_optional && arg["optional"] && arg["type"] != "key"

    input = [arg["token"]].compact

    case arg["type"]
    when "key"
      keys = if arg["multiple"]
               multi_size.times.with_index.map { |i| "#{arg["name"]}#{i + 1}" }
             else
               ["#{arg["name"]}1"]
             end
      output = input.dup
      input += keys
      output += keys.map { |k| "#{namespace}:#{k}" }
    when "pattern"
      patterns = if arg["multiple"]
                   multi_size.times.with_index.map { |i| "#{arg["name"]}#{i + 1}*" }
                 else
                   ["#{arg["name"]}1*"]
                 end
      output = input.dup
      input += patterns
      output += patterns.map { |k| "#{namespace}:#{k}" }
    when "string"
      input << arg["name"]
    when "integer"
      input << (arg["name"] == "numkeys" ? multi_size : Random.rand(1..100))
    when "double"
      input << Random.rand(1.0..100.0).round(2)
    when "unix-time"
      input << Time.now.to_i
    when "pure-token"
      # input << arg["token"]
    when "oneof"
      selected = arg["arguments"].sample
      input << selected["token"] if selected["token"]
      case selected["type"]
      when "integer"
        input << rand(1..100)
      when "unix-time"
        input << Time.now.to_i
      when "block"
        input, output = make_test_case(namespace, selected["token"] || "", selected["arguments"] || [], multi_size: multi_size, non_optional: non_optional)
      end
    when "block"
      # TODO: mutlipule
      input, output = make_test_case(namespace, arg["token"] || "", arg["arguments"] || [], multi_size: multi_size, non_optional: non_optional)
    end
    inputs << input
    outputs << (output || input)
  end
  [inputs.flatten, outputs.flatten.map(&:to_s)]
end

RSpec.describe RedisClient::Namespace do
  describe "all commands tests" do
    namespace = "test"
    builder = RedisClient::Namespace.new(namespace)
    # Load Redis commands
    # from: https://raw.githubusercontent.com/redis/docs/refs/heads/main/data/commands.json
    redis_commands = JSON.parse(File.read(File.join(__dir__, "commands.json")))

    manual_test_commands = %w[
      SUBSCRIBE UNSUBSCRIBE PSUBSCRIBE PUNSUBSCRIBE
      PUBLISH PUBSUB
      XREAD XREADGROUP
      GEORADIUS GEORADIUSBYMEMBER
      MIGRATE
      HSCAN SSCAN ZSCAN
      SORT SORT_RO
    ].freeze

    redis_commands.each do |cmd_name, cmd_info|
      # Skip commands that need manual testing
      next if manual_test_commands.include?(cmd_name.split.first)

      arguments = cmd_info["arguments"] || []

      arguments.any? { |arg| ["key", "pattern"].include?(arg["type"]) }
      has_multiple_key = arguments.any? { |arg| arg["type"] == "key" && arg["multiple"] }
      has_optional_key = arguments.any? { |arg| arg["type"] == "key" && arg["optional"] }
      has_optional_arg = arguments.any? { |arg| arg["type"] != "key" && arg["optional"] }

      testcases = []

      inputs, outputs = make_test_case(namespace, cmd_name, arguments)
      testcases << {
        pattern: "basic",
        inputs: inputs,
        outputs: outputs
      }

      if has_multiple_key
        inputs, outputs = make_test_case(namespace, cmd_name, arguments, multi_size: rand(2..5))
        testcases << {
          pattern: "multi keys",
          inputs: inputs,
          outputs: outputs
        }
      end

      if has_optional_key
        inputs, outputs = make_test_case(namespace, cmd_name, arguments, multi_size: 0)
        testcases << {
          pattern: "no optional keys",
          inputs: inputs,
          outputs: outputs
        }
      end

      if has_optional_arg
        inputs, outputs = make_test_case(namespace, cmd_name, arguments, non_optional: true)
        testcases << {
          pattern: "no optional args",
          inputs: inputs,
          outputs: outputs
        }
      end

      context cmd_name.to_s do
        testcases.each do |t|
          it "#{t[:pattern]}: [#{t[:inputs].map(&:to_s).join(" ")}] -> [#{t[:outputs].map(&:to_s).join(" ")}]" do
            expect(builder.generate(t[:inputs])).to eq(t[:outputs])
          end
        end
      end
    end
  end
end
