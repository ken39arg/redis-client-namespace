# frozen_string_literal: true

require "json"

RSpec.describe RedisClient::Namespace do
  let(:namespace) { "test" }
  let(:builder) { described_class.new(namespace) }

  describe "all commands tests" do
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

    def make_test_case(cmd_name, arguments, multi_size: 1, non_optional: false)
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
            input, output = make_test_case(selected["token"] || "", selected["arguments"] || [], multi_size: multi_size, non_optional: non_optional)
          end
        when "block"
          # TODO: mutlipule
          input, output = make_test_case(arg["token"] || "", arg["arguments"] || [], multi_size: multi_size, non_optional: non_optional)
        end
        inputs << input
        outputs << (output || input)
      end
      [inputs.flatten, outputs.flatten.map(&:to_s)]
    end

    redis_commands.each do |cmd_name, cmd_info|
      # Skip commands that need manual testing
      next if manual_test_commands.include?(cmd_name.split.first)

      arguments = cmd_info["arguments"] || []

      has_key = arguments.any? { |arg| ["key", "pattern"].include?(arg["type"]) }
      has_multiple_key = arguments.any? { |arg| arg["type"] == "key" && arg["multiple"] }
      has_optional_key = arguments.any? { |arg| arg["type"] == "key" && arg["optional"] }
      has_optional_arg = arguments.any? { |arg| arg["type"] != "key" && arg["optional"] }

      context "#{cmd_name} command" do
        if has_key
          it "should transform keys" do
            inputs, outputs = make_test_case(cmd_name, arguments)
            puts "Inputs: #{inputs.inspect}, Outputs: #{outputs.inspect}"
            expect(builder.generate(inputs)).to eq(outputs)
          end

          if has_multiple_key
            it "should handle multiple keys" do
              inputs, outputs = make_test_case(cmd_name, arguments, multi_size: rand(2..5))
              expect(builder.generate(inputs)).to eq(outputs)
            end
          end

          if has_optional_key
            it "should handle optional keys" do
              inputs, outputs = make_test_case(cmd_name, arguments, multi_size: 0)
              expect(builder.generate(inputs)).to eq(outputs)
            end
          end
        else
          it "should not transform. no key arguments" do
            inputs, outputs = make_test_case(cmd_name, arguments)
            expect(builder.generate(inputs)).to eq(outputs)
          end
        end

        if has_optional_arg
          it "should handle optional arguments nothing" do
            inputs, outputs = make_test_case(cmd_name, arguments, non_optional: true)
            puts "Inputs: #{inputs.inspect}, Outputs: #{outputs.inspect}"
            expect(builder.generate(inputs)).to eq(outputs)
          end

        end
      end
    end
  end
end
