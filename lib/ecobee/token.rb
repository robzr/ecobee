module Ecobee

  class Token
    attr_reader :access_token, 
                :expires_at, 
                :pin,
                :pin_message,
                :refresh_token,
                :result,
                :status,
                :scope,
                :type

    def initialize(
      api_key: nil, 
      app_name: DEFAULT_APP_NAME,
      code: nil,
      refresh_token: nil,
      scope: SCOPES[0],
      token_file: nil
    )
      @api_key = api_key
      @app_name = app_name
      @code = code
      @access_token, @expires_at, @pin, @type = nil
      @refresh_token = refresh_token
      @scope = scope
      @status = :authorization_pending
      @token_file = File.expand_path(token_file)
      read_token_file unless @refresh_token
      if @refresh_token
        refresh
      else
        register unless code
        check_for_token
        launch_monitor_thread unless @status == :ready
      end
    end

    def access_token
      refresh if Time.now + REFRESH_INTERVAL_PAD > @expires_at
      @access_token
    end

    def authorization
      "#{@type} #{@access_token}"
    end

    def pin_message
      "Log into Ecobee web portal, select My Apps widget, Add Application, " +
      "enter the PIN #{@pin || ''}"
    end

    def refresh
      response = Net::HTTP.post_form(
        URI(URL_TOKEN),
        'grant_type' => 'refresh_token',
        'refresh_token' => @refresh_token,
        'client_id' => @api_key
      )
      result = JSON.parse(response.body)
      if result.key? 'error'
#        pp result
        raise Ecobee::TokenError.new(
          "Result Error: (%s) %s" % [result['error'],
                                     result['error_description']]
        )
      else
        @access_token = result['access_token']
        @expires_at = Time.now + result['expires_in']
        @refresh_token = result['refresh_token']
        @scope = result['scope']
        @type = result['token_type']
        @status = :ready
        write_token_file
      end
    rescue SocketError => msg
      raise Ecobee::TokenError.new("POST failed: #{msg}")
    rescue JSON::ParserError => msg
      raise Ecobee::TokenError.new("Result parsing: #{msg}")
    rescue Exception => msg
      raise Ecobee::TokenError.new("Unknown Error: #{msg}")
    end

    def wait
      sleep 0.05 while @status == :authorization_pending
      @status
    end

    private

    def check_for_token
      response = Net::HTTP.post_form(
        URI(URL_TOKEN),
        'grant_type' => 'ecobeePin',
        'code' => @code,
        'client_id' => @api_key
      )
      result = JSON.parse(response.body)
      if result.key? 'error'
        unless ['slow_down', 'authorization_pending'].include? result['error']
pp result
          raise Ecobee::TokenError.new(
            "Result Error: (%s) %s" % [result['error'],
                                       result['error_description']]
          )
        end
      else
        @status = :ready
        @access_token = result['access_token']
        @type = result['token_type']
        @expires_at = Time.now + result['expires_in']
        @refresh_token = result['refresh_token']
        @scope = result['scope']
        write_token_file
      end
    rescue SocketError => msg
      raise Ecobee::TokenError.new("POST failed: #{msg}")
    rescue JSON::ParserError => msg
      raise Ecobee::TokenError.new("Result parsing: #{msg}")
    rescue Exception => msg
      raise Ecobee::TokenError.new("Unknown Error: #{msg}")
    end

    def launch_monitor_thread
      Thread.new {
        loop do
          sleep REFRESH_TOKEN_CHECK
          break if @status == :ready
          check_for_token 
        end
      }
    end

    def read_token_file
      tf = File.open(@token_file, 'r').read(16 * 1024)
      config = JSON.parse(tf)
      if config.key? @app_name
        @app_key ||= config[@app_name]['app_key']
        @refresh_token = config[@app_name]['refresh_token']
      end
    rescue Errno::ENOENT
    end

    def register
      result = Register.new(api_key: @api_key, scope: @scope)
      @pin = result.pin
      @code = result.code
      result
    end

    def write_token_file
      return unless @token_file
      File.open(@token_file, 'w') do |tf|
        tf.puts JSON.pretty_generate({
          @app_name => {
            'app_key' => @app_key,
            'refresh_token' => @refresh_token
          }
        })
      end
    end

  end

  class TokenError < StandardError
  end

end
