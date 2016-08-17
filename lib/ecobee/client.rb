module Ecobee

  class Client

    def initialize(token: nil)
      raise ArgumentError.new('Missing token') unless token
      @token = token
    end

    def get(arg, options = nil)
      new_uri = URL_API + arg.to_s.sub(/^\//, '')
      new_uri += '?json=' + options.to_json if options
      request = Net::HTTP::Get.new(URI(URI.escape(new_uri)))
      request['Content-Type'] = *CONTENT_TYPE
      request['Authorization'] = @token.authorization
      http_response = http.request request
      response = validate_status JSON.parse(http_response.body)
#      if response == :retry
#        get(arg, options)
#      else
#        response
#      end
    rescue JSON::ParserError => msg
      raise ClientError.new("JSON::ParserError => #{msg}")
    end

    def post(arg, options: {}, body: nil)
      new_uri = URL_API + arg.to_s.sub(/^\//, '')
      request = Net::HTTP::Post.new(URI new_uri)
      request.set_form_data({ 'format' => 'json' }.merge(options))
      request.body = JSON.generate(body) if body
      request['Content-Type'] = *CONTENT_TYPE
      request['Authorization'] = @token.authorization
      http_response = http.request request
      response = validate_status JSON.parse http_response.body
#      if response == :retry
#        post(arg, options: options, body: body)
#      else
#        response
#      end
    rescue JSON::ParserError => msg
      raise ClientError.new("JSON::ParserError => #{msg}")
    end

    def validate_status(response)
      if !response.key? 'status'
        raise ClientError.new('Missing Status')
      elsif !response['status'].key? 'code'
        raise ClientError.new('Missing Status Code')
      elsif response['status']['code'] == 14 
        :retry
      elsif response['status']['code'] != 0
        raise ClientError.new(
          "GET Error: #{response['status']['code']} " +
          "Message: #{response['status']['message']}"
        )
      else
        response
      end
    end

    private

    def http
      @http ||= Net::HTTP.new(API_HOST, API_PORT)
      unless @http.active? 
        @http.use_ssl = true
        Net::HTTP.start(API_HOST, API_PORT)
      end
      @http
    end

  end

  class ClientError < StandardError ; end

end
