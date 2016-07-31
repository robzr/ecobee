module Ecobee

  class Client

    def initialize(token: nil)
      raise ArgumentError.new('Missing token') unless token
      @token = token
    end

    def get(arg, options = nil)
      new_uri = URI_API + arg.sub(/^\//, '')
      new_uri += '?json=' + options.to_json if options

      uri = URI(new_uri)
      req = Net::HTTP::Get.new(uri)

      req.set_content_type('application/json', { 'charset' => 'UTF-8' })
      req['Authorization'] = "#{@token.type} #{@token.access_token}"

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      res = http.start { |http| http.request(req) }

      #res.is_a?(Net::HTTPSuccess)
      #Net::HTTPBadResponse
      
      res 
    end

    def post
    end

  end

end
