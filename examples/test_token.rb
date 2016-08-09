#!/usr/bin/env ruby
#
# Refreshes token; displays details on saved token.  -- @robzr

require 'pp'
require_relative '../lib/ecobee.rb'

token = Ecobee::Token.new(
  app_key: ENV['ECOBEE_APP_KEY'],
  app_name: 'ecobee-gem'
)

puts token.pin_message if token.pin
token.wait

puts "Access Token: #{token.access_token}"
puts "Refresh Token: #{token.refresh_token}"
puts "Expires At: #{token.access_expires_at}"
puts "Scope: #{token.scope}"
puts "Type: #{token.type}"
