module Ecobee
  require 'date' 

  class Token
    attr_reader :access_expires_at, 
                :access_token, 
                :pin,
                :pin_message,
                :refresh_token,
                :result,
                :status,
                :scope,
                :type

    def initialize(
      access_expires_at: nil,
      access_token: nil,
      app_key: nil,
      app_name: nil,
      code: nil,
      refresh_token: nil,
      scope: SCOPES[0],
      token_file: DEFAULT_FILES
    )
      @access_expires_at = access_expires_at
      @access_token = access_token
      @app_key = app_key
      @app_name = app_name
      @code = code
      @refresh_token = refresh_token
      @scope = scope
      @token_file = expand_files token_file

      @code_expires_at, @pin, @type = nil
      parse_token_file
      @status = @refresh_token ? :ready : :authorization_pending

      if @refresh_token
        refresh
      else
        register unless pin_is_valid
        check_for_token
        launch_monitor_thread unless @status == :ready
      end
    end

    def access_token
      refresh
      @access_token
    end

    def authorization
      "#{@type} #{@access_token}"
    end

    def pin_is_valid
      if @pin && @code && @code_expires_at
        @code_expires_at.to_i >= DateTime.now.strftime('%s').to_i
      else
        false
      end
    end

    def pin_message
      "Log into Ecobee web portal, select My Apps widget, Add Application, " +
      "enter the PIN #{@pin || ''}"
    end

    def refresh
      return if Time.now.to_i + REFRESH_INTERVAL_PAD < @access_expires_at
      response = Net::HTTP.post_form(
        URI(URL_TOKEN),
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
        @access_token = result['access_token']
        @access_expires_at = Time.now.to_i + result['expires_in']
        @refresh_token = result['refresh_token']
        @pin, @code, @code_expires_at = nil
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
        'client_id' => @app_key
      )
      result = JSON.parse(response.body)
      if result.key? 'error'
        unless ['slow_down', 'authorization_pending'].include? result['error']
          # TODO: throttle or just ignore...?
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
        @access_expires_at = Time.now.to_i + result['expires_in']
        @refresh_token = result['refresh_token']
        @scope = result['scope']
        @pin, @code, @code_expires_at = nil
        write_token_file
      end
    rescue SocketError => msg
      raise Ecobee::TokenError.new("POST failed: #{msg}")
    rescue JSON::ParserError => msg
      raise Ecobee::TokenError.new("Result parsing: #{msg}")
    rescue Exception => msg
      raise Ecobee::TokenError.new("Unknown Error: #{msg}")
    end

    def expand_files(token_file)
      if token_file.is_a? Array
        token_file.map { |tf| File.expand_path tf }
      else
        expand_files [token_file]
      end
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

    def parse_token_file
      return unless (all_config = read_token_file).is_a? Hash
      section = (@app_name && all_config.key?(@app_name)) ? @app_name : @app_key
      return unless all_config.key?(section)
      config = all_config[section]
      @app_key ||= config.key?('app_key') ? config['app_key'] : @app_name
      if config.key?('refresh_token')
        @access_expires_at ||= config['access_expires_at'].to_i
        @access_token ||= config['access_token']
        @refresh_token ||= config['refresh_token']
        @scope ||= config['scope']
        @type ||= config['token_type']
      elsif config.key?('pin')
        @code ||= config['code']
        @code_expires_at ||= config['code_expires_at'].to_i
        @pin ||= config['pin']
      end
    end

    def read_json_file(file)
      JSON.parse(
        File.open(file, 'r').read(16 * 1024)
      )
    rescue JSON::ParserError => msg
      raise Ecobee::TokenError.new("Result parsing: #{msg}")
    rescue Errno::ENOENT
      {}
    end

    def read_token_file
      @token_file.each do |tf|
         result = read_json_file(tf)
         return result if result.length > 0
      end
    end

    def register
      result = Register.new(app_key: @app_key, scope: @scope)
      @pin = result.pin
      @code = result.code
      @code_expires_at = result.expires_at
      @scope = result.scope
      write_token_file
      result
    end

    def write_token_file
      @token_file.each do |file|
        return if write_json_file file
      end
    end

    def write_json_file(file)
      if config = read_token_file
        config.delete(@app_name)
        config.delete(@app_key)
      end
      section = @app_name || @app_key
      config[section] = {}
      config[section]['app_key'] = @app_key if @app_key && section != @app_key
      if @refresh_token
        config[section]['access_token'] = @access_token 
        config[section]['access_expires_at'] = @access_expires_at
        config[section]['refresh_token'] = @refresh_token 
        config[section]['token_type'] = @type
        config[section]['scope'] = @scope
      elsif @pin
        config[section]['pin'] = @pin
        config[section]['code'] = @code
        config[section]['code_expires_at'] = @code_expires_at
      end
      File.open(file, 'w') do |tf|
        tf.puts JSON.pretty_generate(config)
      end
      true
    rescue Errno::ENOENT
      nil
    end

  end

  class TokenError < StandardError
  end

end
