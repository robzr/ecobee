module Ecobee

  class Register
    attr_reader :result

    def initialize(api_key: nil, scope: SCOPES[0])
      raise ArgumentError.new('Missing api_key') unless api_key

      @result = get_pin(api_key: api_key, scope: scope)
    end

    def code
      @result['code']
    end

    def interval
      @result['interval']
    end

    def pin
      @result['ecobeePin']
    end

    private 

    def get_pin(api_key: nil, scope: nil)
      uri_pin = URI(URL_GET_PIN % [api_key, scope.to_s])
      result = JSON.parse Net::HTTP.get(uri_pin)
      if result.key? 'error'
        raise Ecobee::RegisterError.new(
          "Result Error: (%s) %s" % [result['error'], result['error_description']]
        )
      end
      result
    rescue SocketError => msg
      raise Ecobee::RegisterError.new("GET failed: #{msg}")
    rescue JSON::ParserError => msg
      raise Ecobee::RegisterError.new("Result parsing: #{msg}")
    rescue Exception => msg
      raise Ecobee::RegisterError.new("Unknown Error: #{msg}")
    end
  end

  class RegisterError < StandardError
  end

end
