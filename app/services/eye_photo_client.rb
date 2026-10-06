require 'json'
require 'net/http'
require 'uri'

class EyePhotoClient
  class UnavailableError < StandardError; end

  LOOKUP_PATH = '/api/admin/studios/lookup'.freeze

  def lookup(email:, api_key:)
    raise UnavailableError, 'Eye.photo is not configured for this inbox' if api_key.blank?

    uri = URI.join(base_url, LOOKUP_PATH)
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Token #{api_key}"
    request['Content-Type'] = 'application/json'
    request.body = { email: email }.to_json

    response = Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: uri.scheme == 'https',
      open_timeout: 2,
      read_timeout: 8
    ) { |http| http.request(request) }

    raise UnavailableError, 'Eye.photo could not retrieve studio data' unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue SocketError, Timeout::Error, Errno::ECONNREFUSED, JSON::ParserError => e
    raise UnavailableError, "Eye.photo could not retrieve studio data: #{e.message}"
  end

  private

  def base_url
    ENV.fetch('EYE_PHOTO_API_URL', 'https://eye.photo')
  end
end
