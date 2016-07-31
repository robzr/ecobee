module Ecobee

  class Token
    attr_reader :access_token, 
                :expires_at, 
                :expires_in,
                :pin,
                :pin_message,
                :refresh_token,
                :result,
                :status,
                :scope,
                :type

    def initialize(
      app_key: GEM_APP_KEY, 
      code: nil,
      refresh_token: nil,
      scope: SCOPES[0],
      token_file: nil
    )
      @app_key = app_key
      @code = code
      @interval = DEFAULT_INTERVAL
      @pin = nil
      @refresh_token = refresh_token
      @scope = scope
      @status = :authorization_pending
      @token_file = File.expand_path(token_file)
      read_token_file unless @refresh_token
      if @refresh_token
        refresh
      else
        register unless code
        get_token
        launch_monitor_thread
      end
    end

    def access_token
      refresh if Time.now + PRE_REFRESH_INTERVAL > @expires_at
      @access_token
    end

    def pin_message
      "Log into Ecobee web portal, select My Apps widget, Add Application, " +
      "enter the PIN #{@pin || ''}"
    end

    def refresh
      response = Net::HTTP.post_form(
        URI(URI_TOKEN),
        'grant_type' => 'refresh_token',
        'refresh_token' => @refresh_token,
        'client_id' => @app_key
      )
      result = JSON.parse(response.body)
      if result.key? 'error'
        pp result
        raise Ecobee::TokenError.new(
          "Result Error: (%s) %s" % [result['error'],
                                     result['error_description']]
        )
      else
        @status = :ready
        @access_token = result['access_token']
        @type = result['token_type']
        @expires_in = result['expires_in']
        @expires_at = Time.now + @expires_in
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

    def wait
      sleep 0.05 while @status == :authorization_pending
      @status
    end

    private

    def get_token
      response = Net::HTTP.post_form(
        URI(URI_TOKEN),
        'grant_type' => 'ecobeePin',
        'code' => @code,
        'client_id' => @app_key
      )
      result = JSON.parse(response.body)
      if result.key? 'error'
        unless result['error'] == 'authorization_pending'
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
        @expires_in = result['expires_in']
        @expires_at = Time.now + @expires_in
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
          sleep @interval
          break if @status == :ready
          get_token 
        end
      }
    end

    def read_token_file
      File.open(@token_file, 'r') do |tf|
        @refresh_token = tf.gets.chomp
      end
    rescue Errno::ENOENT
    end

    def write_token_file
      return unless @token_file
      File.open(@token_file, 'w') do |tf|
        tf.puts @refresh_token
      end
    end

    def register
      result = Register.new(app_key: @app_key, scope: @scope)
      @pin = result.pin
      @code = result.code
      @interval = result.interval
      result
    end

  end

  class TokenError < StandardError
  end

end
