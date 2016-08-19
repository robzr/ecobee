module Ecobee

  class Token
    attr_reader :access_token, 
                :access_token_expire, 
                :app_key,
                :callbacks,
                :http,
                :pin,
                :refresh_token,
                :result,
                :status,
                :scope,
                :token_file,
                :token_type

    #AUTH_ERRORS = %w(slow_down authorization_pending authorization_expired)

    @STATUSES = {
      authorization_pending: 'Registration begun but has not been approved.',
      ready:                 'Registration approved and valid token received.'
    }

    def initialize(
      access_token: nil,
      access_token_expire: nil,
      app_key: nil,
      callbacks: {},
      log_file: nil,
      refresh_token: nil,
      scope: SCOPES[0],
      token_file: DEFAULT_FILES
    )
      @access_token = access_token
      @access_token_expire = access_token_expire
      @app_key = app_key
      @callbacks = callbacks
      @refresh_token = refresh_token
      @scope = scope
      @token_file = expand_files token_file

      @authorization_thread, @pin, @status, @token_type = nil
      @poll_interval = DEFAULT_POLL_INTERVAL

      @http = Ecobee::HTTP.new(log_file: log_file, token: self)

      @refresh_pad = REFRESH_PAD + rand(REFRESH_PAD)

      config_load
      access_token()
    end

    def access_token
     if @access_token
       if access_token_expired?
         if @refresh_token
           @http.log "access_token: refreshing #{@access_token}, #{@access_token_expire}, #{Time.now.to_i}"
           refresh_access_token
         else
           @http.log "access_token: token_register"
           token_register 
         end
       else
         desired_status = (@refresh_token ? :ready : :authorization_pending)
         if @refresh_token
           if @status != desired_status
             puts "Status: MISMATCH: #{@status} vs #{desired_status}" if @status
             @status = desired_status
           end
           @http.log "access_token: good #{@access_token}, #{@access_token_expire}, #{Time.now.to_i}"
           @access_token
         else
           @http.log "access_token: check_for_authorization #{@access_token}, #{@access_token_expire}"
           check_for_authorization
         end
       end
     else
       @status = :authorization_pending
       token_register 
     end
    end

    def access_token_expired?
      return true unless @access_token_expire
      Time.now.to_i > @access_token_expire - @refresh_pad
    end

    def authorization
      "#{@token_type} #{access_token}"
    end

    def config_load
      config = config_read_our_section
      if @callbacks[:load].respond_to? :call
        config = @callbacks[:load].call(config)
      end
      config_load_to_memory config
    end

    def config_save
      config = config_dump()
      if @callbacks[:save].respond_to? :call
        config = @callbacks[:save].call(config)
      end
      config_write_section config
    end

    def pin_is_valid
      if @pin && @access_token && @access_token_expire
        @access_token_expire.to_i >= Time.now.to_i
      end
    end

    def pin_message
      "Log into Ecobee web portal, select My Apps widget, Add Application, " +
      "enter the PIN #{@pin || ''}"
    end

    def refresh_access_token
      arg = sprintf("?grant_type=refresh_token&refresh_token=%s&client_id=%s",
                    @refresh_token,
                    @app_key)
      result = @http.post(arg: arg,
                          no_auth: true,
                          resource_prefix: 'token',
                          validate_status: false)
      if result.key? 'error'
        @access_token, @access_token_expire, @pin, @scope, @refresh_token = nil
        config_save
        raise Ecobee::AuthError.new(
          "Result Error: (%s) %s" % [result['error'],
                                     result['error_description']]
        )
      else
        @access_token = result['access_token']
        @access_token_expire = Time.now.to_i + result['expires_in']
        @pin = nil
        @refresh_token = result['refresh_token']
        @scope = result['scope']
        @token_type = result['token_type']
        @status = :ready
        config_save
        @access_token
      end 
    end

    def register_callback(type, *callback, &block)
      if block_given?
        puts "Registering #{type}"
        @callbacks[type] = block
      else
        @callbacks[type] = callback[0] if callback.length > 0
      end
    end

    def wait(timeout: nil)
      if timeout
        Timeout::timeout(timeout) { wait(timeout: nil) }
      else
        sleep 0.01 while @status == :authorization_pending
      end
    rescue Timeout::Error
    ensure
      @status
    end

    private

    # arrives here, expired
    def check_for_authorization
      check_for_authorization_single
      if @status == :authorization_pending
        unless @authorization_thread && @authorization_thread.alive?
          @authorization_thread = Thread.new {
            loop do
              puts "Sleeping for #{@poll_interval}"
              sleep @poll_interval
              break if @status == :ready
              puts "check_for_authorization_single"
              check_for_authorization_single
            end
          }
        end
      end
    end

    def check_for_authorization_single
      arg = sprintf("?grant_type=ecobeePin&code=%s&client_id=%s",
                    @access_token,
                    @app_key)
      result = @http.post(arg: arg,
                          no_auth: true,
                          resource_prefix: 'token',
                          validate_status: false)
      if result.key? 'error'
        @status = :authorization_pending
        if result['error'] == 'invalid_client'
          token_register 
        elsif ['slow_down', 'authorization_pending'].include? result['error']
          nil
        else
          @access_token, @access_token_expire, @pin, @scope, @refresh_token = nil
          config_save
          raise Ecobee::AuthError.new(
            "Result Error: (%s) %s" % [result['error'],
                                       result['error_description']]
          )
        end
      else
        @status = :ready
        @access_token = result['access_token']
        @token_type = result['token_type']
        @access_token_expire = Time.now.to_i + result['expires_in']
        @refresh_token = result['refresh_token']
        @scope = result['scope']
        @pin = nil
        config_save
        @access_token
      end
    end

    def config_load_to_memory(config)
      @app_key ||= config['app_key']
      if !@access_token
        @access_token = config['access_token']
        @access_token_expire = config['access_token_expire'].to_i
      elsif(config.key?('access_token') && 
            config['access_token_expire'].to_i > @access_token_expire)
        @access_token = config['access_token']
        @access_token_expire = config['access_token_expire'].to_i
        if config['refresh_token']
          @refresh_token = config['refresh_token'] 
          @scope = config['scope']
          @token_type = config['token_type']
        elsif config.key?('pin')
          @pin = config['pin']
        end
      end
      if config.key?('refresh_token')
        @refresh_token ||= config['refresh_token']
        @scope ||= config['scope']
        @token_type ||= config['token_type']
      elsif config.key?('pin')
        @pin ||= config['pin']
      end
    end

    def config_read_our_section
      all_config = config_read_all_sections
      if @app_name && all_config.key?(@app_name)
        our_section = @app_name
      else
        our_section = @app_key
      end
      return all_config[our_section] || {}
    end

    def config_read_all_sections
      @token_file.each do |tf|
         result = config_read_file(tf)
         return result if result.length > 0
      end
      {}
    end

    def config_read_file(file)
      JSON.parse(
        File.open(file, 'r').read(16 * 1024)
      )
    rescue JSON::ParserError => msg
      raise Ecobee::AuthError.new("Result parsing: #{msg}")
    rescue Errno::ENOENT
      {}
    end

    def config_dump
      config = {}
      config['access_token'] = @access_token
      config['access_token_expire'] = @access_token_expire
      if @refresh_token
        config['refresh_token'] = @refresh_token 
        config['scope'] = @scope
        config['token_type'] = @token_type
      elsif @pin
        config['pin'] = @pin
      end
      config
    end

    def config_write_section(config)
      all_config = config_read_all_sections
      all_config.delete(@app_key)
      all_config[@app_key] = config

      @token_file.each do |file_name|
        return true if config_write_file(config: all_config, file_name: file_name)
      end
      nil
    end

    def config_write_file(config: nil, file_name: nil)
      File.open(file_name, 'w') do |file|
        file.puts JSON.pretty_generate(config)
      end
      true
    rescue Errno::ENOENT
      nil
    end

    def expand_files(token_file)
      if token_file.is_a? NilClass
        nil
      elsif token_file.is_a? Array
        token_file.map { |tf| File.expand_path tf }
      else
        expand_files [token_file]
      end
    end

    def token_register
      @status = :authorization_pending
      result = Ecobee::Register.new(app_key: @app_key,
                                    http: @http,
                                    scope: @scope)
      @poll_interval = result.interval
      @pin = result.pin
      @access_token = result.code
      @access_token_expire = result.expire
      @refresh_token = nil
      @scope = result.scope
      check_for_authorization
      config_save
      @access_token
    end

  end

end
