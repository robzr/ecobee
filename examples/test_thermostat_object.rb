#!/usr/bin/env ruby

require 'pp'
require 'benchmark'

require_relative '../lib/ecobee'

token = Ecobee::Token.new(app_key: ENV['ECOBEE_APP_KEY'])
if token.pin
  puts token.pin_message 
  token.wait 
end

thermostat = Ecobee::Thermostat.new(token: token)

puts "Mode: " + thermostat[:settings][:hvacMode]

#thermostat[:devices][0][:sensors].each do |sensor|
#  puts "Sensor: #{sensor[:name]}"
#end

#puts thermostat.keys

#thermostat[:program][:climates].each do |climate|
#  puts "Climate: #{climate[:name]}"
#end
#
