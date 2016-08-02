#!/usr/bin/env ruby

require 'pp'
require_relative '../lib/ecobee'

HVAC_MODES = ['auto', 'auxHeatOnly', 'cool', 'heat', 'off', 'quit']

class TestFunctions
  def initialize(client)
    @client = client
  end

  def print_summary
    http_response = @client.get(
      'thermostat', 
      { 
        'selection' => {
          'selectionType' => 'registered',
          'selectionMatch' => '', 
          'includeEquipmentStatus' => 'true',
          'includeSettings' => 'true'
        }
      }
    )
    response = JSON.parse(http_response.body)

    puts "Found %d thermostats." % response['thermostatList'].length

    response['thermostatList'].each do |stat|
      printf(
        " -> %s (%s %s) Mode: %s Status: %s\n",
        stat['name'],
        stat['brand'],
        Ecobee::Model(stat['modelNumber']),
        stat['settings']['hvacMode'],
        stat['equipmentStatus']
      )
    end
  end

  def update_mode(mode)
    http_response = @client.post(
      'thermostat', 
      body: { 
        'selection' => {
          'selectionType' => 'registered',
          'selectionMatch' => '',
        },
        'thermostat' => {
          'settings' => {
            'hvacMode' => mode
          }
        }
      }
    )
    response = JSON.parse(http_response.body)
  end

end


token = Ecobee::Token.new(
  api_key: ENV['ECOBEE_API_KEY'],
  scope: :smartWrite,
  token_file: '~/.ecobee_token'
)

puts token.pin_message if token.pin
token.wait

test_functions = TestFunctions.new(Ecobee::Client.new(token: token))

loop do
  test_functions.print_summary

  answer = -1
  while !answer.between?(0, HVAC_MODES.length)
    puts
    (1..HVAC_MODES.length).each do |num|
      printf "%d) %s\n", num, HVAC_MODES[num - 1]
    end
    print "Enter mode: "
    answer = gets.to_i - 1
    abort if answer == (HVAC_MODES.length - 1)
  end
  puts

  result = test_functions.update_mode(HVAC_MODES[answer])

  unless result.key?('status') && (result['status']['code'] == 0)
    puts "Unknown result: #{result.to_s}\n" 
  end
end
