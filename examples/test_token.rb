#!/usr/bin/env ruby
#
# Refreshes token; displays details on saved token.  -- @robzr

require 'pp'

require_relative '../lib/ecobee'

load_lambda = lambda do |config|
  config
end

save_lambda = lambda do |config|
  config
end

token = Ecobee::Token.new(
  app_key: ENV['ECOBEE_APP_KEY'],
  callbacks: { 
    load: load_lambda,
    save: save_lambda
  }
)

puts token.pin_message if token.pin
token.wait

token.config_save

puts "APP Key: #{token.app_key}"
puts "Access Token: #{token.access_token}"
puts "Refresh Token: #{token.refresh_token}"
puts "Expires At: #{token.access_token_expire}"
puts "Scope: #{token.scope}"
puts "Type: #{token.token_type}"
