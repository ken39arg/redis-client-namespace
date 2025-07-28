# frozen_string_literal: true

require "spec_helper"

RSpec.describe RedisClient::Namespace do
  let(:builder) { described_class.new("test") }

  describe "#generate" do
    context "GET/SET commands" do
      it "adds namespace to GET command" do
        result = builder.generate(["GET", "key"])
        expect(result).to eq(["GET", "test:key"])
      end

      it "adds namespace to SET command" do
        result = builder.generate(["SET", "key", "value"])
        expect(result).to eq(["SET", "test:key", "value"])
      end
    end

    context "MGET/MSET commands" do
      it "processes multiple keys for MGET command" do
        result = builder.generate(["MGET", "key1", "key2", "key3"])
        expect(result).to eq(["MGET", "test:key1", "test:key2", "test:key3"])
      end

      it "correctly processes multiple keys for MSET" do
        result = builder.generate(["MSET", "key1", "val1", "key2", "val2"])
        expect(result).to eq(["MSET", "test:key1", "val1", "test:key2", "val2"])
      end
      it "doesn't crash with odd number of arguments for MSET (invalid command)" do
        result = builder.generate(["MSET", "key1", "val1", "key2"])
        expect(result).to eq(["MSET", "test:key1", "val1", "test:key2"])
      end
    end

    context "EVALSHA/EVAL commands" do
      it "processes normal EVAL command" do
        result = builder.generate(["EVAL", "script", "2", "key1", "key2", "arg1"])
        expect(result).to eq(["EVAL", "script", "2", "test:key1", "test:key2", "arg1"])
      end

      it "processes normal EVALSHA command" do
        result = builder.generate(["EVALSHA", "sha1hash", "1", "key1", "arg1", "arg2"])
        expect(result).to eq(["EVALSHA", "sha1hash", "1", "test:key1", "arg1", "arg2"])
      end

      it "processes when numkeys is 0" do
        result = builder.generate(["EVAL", "script", "0", "arg1", "arg2"])
        expect(result).to eq(["EVAL", "script", "0", "arg1", "arg2"])
      end

      it "doesn't crash when numkeys is greater than actual keys (bug case)" do
        result = builder.generate(["EVAL", "script", "5", "key1"])
        expect(result).to eq(["EVAL", "script", "5", "test:key1"])
      end

      it "doesn't crash when numkeys is negative" do
        result = builder.generate(["EVAL", "script", "-1", "key1"])
        expect(result).to eq(["EVAL", "script", "-1", "key1"])
      end

      it "doesn't crash when command is too short" do
        result = builder.generate(["EVAL", "script"])
        expect(result).to eq(["EVAL", "script"])
      end
    end

    context "SCRIPT commands" do
      it "SCRIPT command doesn't change keys" do
        result = builder.generate(["SCRIPT", "FLUSH"])
        expect(result).to eq(["SCRIPT", "FLUSH"])
      end

      it "SCRIPT LOAD command doesn't change keys" do
        result = builder.generate(["SCRIPT", "LOAD", "return 1"])
        expect(result).to eq(["SCRIPT", "LOAD", "return 1"])
      end
    end

    context "SCAN command processing" do
      it "processes SCAN command with MATCH option" do
        result = builder.generate(["SCAN", "0", "MATCH", "prefix*", "COUNT", "10"])
        expect(result).to eq(["SCAN", "0", "MATCH", "test:prefix*", "COUNT", "10"])
      end

      it "HSCAN command" do
        result = builder.generate(["HSCAN", "hash", "0", "MATCH", "field*"])
        expect(result).to eq(["HSCAN", "test:hash", "0", "MATCH", "field*"])
      end

      it "HSCAN command without MATCH option" do
        result = builder.generate(["HSCAN", "hash", "0"])
        expect(result).to eq(["HSCAN", "test:hash", "0"])
      end

      it "SCAN command without MATCH option" do
        result = builder.generate(["SCAN", "0", "COUNT", "10"])
        expect(result).to eq(["SCAN", "0", "COUNT", "10"])
      end
    end

    context "SORT command processing" do
      # SORT command
      it "SORT command" do
        result = builder.generate(["SORT", "list"])
        expect(result).to eq(["SORT", "test:list"])
      end

      it "processes SORT command with BY, GET, STORE options" do
        result = builder.generate(["SORT", "list", "BY", "weight_*", "GET", "object_*", "STORE", "result"])
        expect(result).to eq(["SORT", "test:list", "BY", "test:weight_*", "GET", "test:object_*", "STORE", "test:result"])
      end

      it "processes SORT command with GET #" do
        result = builder.generate(["SORT", "list", "GET", "#"])
        expect(result).to eq(["SORT", "test:list", "GET", "#"])
      end
    end

    context "any cases" do
      it "processes single element command" do
        result = builder.generate(["PING"])
        expect(result).to eq(["PING"])
      end

      it "is case insensitive" do
        result = builder.generate(["get", "key"])
        expect(result).to eq(["get", "test:key"])
      end

      it "raises error for unknown commands" do
        expect do
          builder.generate(["UNKNOWN", "key", "value"])
        end.to raise_error(RedisClient::Namespace::Error, "RedisClient::Namespace does not know how to handle 'UNKNOWN'.")
      end

      it "processes command passed as symbol" do
        result = builder.generate([:set, :foo, 1])
        expect(result).to eq(["set", "test:foo", "1"])
      end
    end
  end

  describe "key options" do
    context "when separator is set" do
      let(:builder) { described_class.new("test2", separator: "-") }

      it "uses the custom separator for keys" do
        result = builder.generate(["GET", "key:b"])
        expect(result).to eq(["GET", "test2-key:b"])
      end
    end

    context "nested builder" do
      let(:parent_builder) { described_class.new("test1", separator: ":") }
      let(:nested_builder) { described_class.new("test2", separator: "-", parent_command_builder: parent_builder) }

      it "uses the parent namespace for nested builder" do
        result = nested_builder.generate(["GET", "key:b"])
        expect(result).to eq(["GET", "test2-test1:key:b"])
      end
    end

    context "when empty namespace" do
      let(:builder) { described_class.new("") }

      it "returns as-is when namespace is empty" do
        result = builder.generate(["GET", "key"])
        expect(result).to eq(["GET", "key"])
      end
    end
  end
end
