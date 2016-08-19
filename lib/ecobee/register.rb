module Ecobee

  class Register
    attr_reader :expire, :result

    def initialize(
      app_key: nil,
      http: nil,
      scope: DEFAULT_SCOPE
    )
      @result = get_pin(app_key: app_key, http: http, scope: scope)
      @expire = Time.now.to_i + result['expires_in'] * 60
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

    def scope
      @result['scope']
    end

    private

    def get_pin(app_key: nil, http: nil, scope: nil)
      scope = scope.to_s if scope.is_a? Symbol
      arg = "?response_type=ecobeePin&client_id=#{app_key}&scope=#{scope}"
      result = http.get(arg: arg,
                        no_auth: true,
                        resource_prefix: 'authorize',
                        validate_status: false)
      if result.key? 'error'
        raise Ecobee::AuthError.new(
          "Register Error: (#{result['error']}) #{result['error_description']}"
        )
      else
        result
      end
    end

  end

end
