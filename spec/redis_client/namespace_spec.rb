# frozen_string_literal: true

RSpec.describe RedisClient::Namespace do
  it "has a version number" do
    expect(RedisClient::Namespace::VERSION).not_to be nil
  end
end
