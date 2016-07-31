module Ecobee

  class Register
    attr_reader :result

    def initialize(app_key: GEM_APP_KEY, scope: SCOPES[0])
      @app_key = app_key
      @scope = scope.to_s
      @result = get_pin
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

    def get_pin
      uri_pin = URI(URI_PIN % [@app_key, @scope])
      result = JSON.parse Net::HTTP.get uri_pin
      if result.key? 'error'
        raise Ecobee::PinError.new(
          "Result Error: (%s) %s" % [result['error'], result['error_description']]
        )
      end
      result
    rescue SocketError => msg
      raise Ecobee::PinError.new("GET failed: #{msg}")
    rescue JSON::ParserError => msg
      raise Ecobee::PinError.new("Result parsing: #{msg}")
    rescue Exception => msg
      raise Ecobee::PinError.new("Unknown Error: #{msg}")
    end
  end

  class PinError < StandardError
  end

end
