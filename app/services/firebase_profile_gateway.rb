require 'json'
require 'net/http'
require 'uri'

class FirebaseProfileGateway
  class UnavailableError < StandardError; end

  def lookup(email)
    uri = URI.join(url, '/v1/profile')
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{token}"
    request['Content-Type'] = 'application/json'
    request.body = { email: email }.to_json

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 2, read_timeout: 8) do |http|
      http.request(request)
    end
    raise UnavailableError, 'Firebase profile service is unavailable' unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue SocketError, Timeout::Error, Errno::ECONNREFUSED, JSON::ParserError => e
    raise UnavailableError, "Firebase profile service is unavailable: #{e.message}"
  end

  private

  def url
    ENV.fetch('FIREBASE_PROFILE_GATEWAY_URL')
  rescue KeyError
    raise UnavailableError, 'Firebase profile integration is not configured'
  end

  def token
    ENV.fetch('FIREBASE_PROFILE_GATEWAY_TOKEN')
  rescue KeyError
    raise UnavailableError, 'Firebase profile integration is not configured'
  end
end
