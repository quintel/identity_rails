# frozen_string_literal: true

module HTTPClientHelpers
  # Creates a new HTTP client for testing requests.
  def self.fake_client(&block)
    Faraday.new do |builder|
      builder.request(:json)
      builder.response(:json)

      builder.adapter(:test, &block)
    end
  end
end
