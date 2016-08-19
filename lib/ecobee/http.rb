module Ecobee

  class HTTPError < StandardError ; end
  class AuthError < HTTPError ; end

  class HTTP

    def initialize(log_file: nil, token: nil)
      raise ArgumentError.new('Missing token') unless token
      @token = token
      open_log log_file
      http
    end

    def get(
      arg: nil,
      no_auth: false,
      resource_prefix: '1/',
      retries: 3,
      options: nil,
      validate_status: true
    )
      uri = URI.escape(sprintf("#{Ecobee::API_URI_BASE}/%s%s%s",
                               resource_prefix,
                               arg.to_s.sub(/^\//, ''),
                               options ? "?json=#{options.to_json}" : ''))
      log "http.get uri=#{uri}"
      request = Net::HTTP::Get.new(URI(uri))
      request['Content-Type'] = *CONTENT_TYPE
      request['Authorization'] = @token.authorization unless no_auth
      response = nil
      retries.times do
        http_response = http.request request
        response = JSON.parse(http_response.body)
        log "http.get response=#{response.pretty_inspect}"
        response = validate_status(response) if validate_status
        break unless response == :retry
        sleep 3
      end
      case response
      when :retry
        raise Ecobee::HTTPError.new('HTTP.get: retries exhausted')
      else
        response
      end
    rescue SocketError => msg
      raise Ecobee::HTTPError.new("HTTP.get SocketError => #{msg}")
    rescue JSON::ParserError => msg
      raise Ecobee::HTTPError.new("HTTP.get JSON::ParserError => #{msg}")
    end

    def log(arg)
      return unless @log_fh
      if arg.length > MAX_LOG_LENGTH
        arg = arg.slice(0, MAX_LOG_LENGTH).chomp + "\n ...truncated..."
      end
      @log_fh.puts "#{Time.now} #{arg.chomp}"
      @log_fh.flush
    end

    def post(
      arg: nil,
      body: nil,
      no_auth: false,
      resource_prefix: '1/',
      retries: 3,
      options: {},
      validate_status: true
    )
      uri = URI.escape(sprintf("#{Ecobee::API_URI_BASE}/%s%s%s",
                               resource_prefix,
                               arg.to_s.sub(/^\//, ''),
                               options.length > 0 ? "?json=#{options.to_json}" : ''))
      log "http.post uri=#{uri}"
      request = Net::HTTP::Post.new(URI(uri))
      request['Content-Type'] = *CONTENT_TYPE
      request['Authorization'] = @token.authorization unless no_auth
      if body
        log "http.post body=#{body.pretty_inspect}"
        request.body = JSON.generate(body)
      elsif options.length > 0
        request.set_form_data({ 'format' => 'json' }.merge(options))
      end
      response = nil
      retries.times do
        http_response = http.request request
        response = JSON.parse(http_response.body)
        log "http.post response=#{response.pretty_inspect}"
        response = validate_status(response) if validate_status
        break unless response == :retry
        sleep 3
      end
      case response
      when :retry
        raise Ecobee::HTTPError.new('HTTP.get: retries exhausted')
      else
        response
      end
    rescue SocketError => msg
      raise Ecobee::HTTPError.new("HTTP.get SocketError => #{msg}")
    rescue JSON::ParserError => msg
      raise Ecobee::HTTPError.new("HTTP.get JSON::ParserError => #{msg}")
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

    def open_log(log_file)
      return unless log_file
      log_file = File.expand_path log_file
      @log_fh = File.new(log_file, 'a')
    rescue Exception => msg 
      raise Ecobee::HTTPError.new("open_log: #{msg}")
    end

    def validate_status(response)
      if !response.key? 'status'
        raise Ecobee::HTTPError.new('Validate Error: Missing Status')
      elsif !response['status'].key? 'code'
        raise Ecobee::HTTPError.new('Validate Error: Missing Status Code')
      elsif response['status']['code'] == 14
        :retry
      elsif response['status']['code'] != 0
        raise Ecobee::HTTPError.new(
          "Validate Error: (Code #{response['status']['code']}) " +
          "#{response['status']['message']}"
        )
      else
        response
      end
    end

  end

end
