#!/usr/bin/env ruby
#
# Refreshes token; displays details on saved token.  -- @robzr

require 'pp'
require 'ecobee'
require_relative '/Users/robzr/GitHub/ecobee/lib/ecobee/token.rb'
require_relative '/Users/robzr/GitHub/ecobee/lib/ecobee/register.rb'

token = Ecobee::Token.new(
  app_key: ENV['ECOBEE_API_KEY'],
  app_name: 'ecobee-gem',
  token_file: '~/.ecobee_token'
)

puts token.pin_message if token.pin
token.wait

puts "Access Token: #{token.access_token}"
puts "Refresh Token: #{token.refresh_token}"
puts "Expires At: #{token.expires_at}"
puts "Scope: #{token.scope}"
puts "Type: #{token.type}"
