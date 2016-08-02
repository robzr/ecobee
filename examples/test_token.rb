#!/usr/bin/env ruby

require 'pp'
require 'ecobee'

token = Ecobee::Token.new(
  api_key: ENV['ECOBEE_API_KEY'],
  token_file: '~/.ecobee_token'
)

puts token.pin_message if token.pin
token.wait

puts "Access Token: #{token.access_token}"
puts "Refresh Token: #{token.refresh_token}"
puts "Expires At: #{token.expires_at}"
puts "Scope: #{token.scope}"
puts "Type: #{token.type}"
