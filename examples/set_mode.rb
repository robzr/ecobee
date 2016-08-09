#!/usr/bin/env ruby
#
# Loops through menu showing current thermostat mode, with option
# to change the mode.       -- @robzr

require 'pp'

require 'ecobee'

@hvac_modes = Ecobee::HVAC_MODES + ['quit']

class TestFunctions
  def initialize(client)
    @client = client
  end

  def print_summary
    response = @client.get(
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
    @client.post(
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
  end
end

token = Ecobee::Token.new(app_key: ENV['ECOBEE_APP_KEY'])

puts token.pin_message if token.pin
token.wait 
test_functions = TestFunctions.new(
  Ecobee::Client.new(token: token)
)

loop do
  test_functions.print_summary

  answer = -1
  until answer.between?(0, @hvac_modes.length - 1)
    puts
    (1..@hvac_modes.length).each do |num|
      printf "%d) %s\n", num, @hvac_modes[num - 1]
    end
    print "Enter mode: "
    answer = gets.to_i - 1
    abort if answer == (@hvac_modes.length - 1)
  end
  puts

  result = test_functions.update_mode(@hvac_modes[answer])

  unless result.key?('status') && (result['status']['code'] == 0)
    puts "Unknown result: #{result.to_s}\n" 
  end
end
