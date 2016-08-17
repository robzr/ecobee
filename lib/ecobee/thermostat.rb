module Ecobee
  class ThermostatError < StandardError ; end

  class Thermostat < Hash

    DEFAULT_SELECTION_ARGS = {
      includeRuntime: true,
      includeExtendedRuntime: true,
      includeElectricity: true,
      includeSettings: true,
      includeLocation: true,
      includeProgram: true,
      includeEvents: true,
      includeDevice: true,
      includeTechnician: true,
      includeUtility: true,
      includeAlerts: true,
      includeWeather: true,
      includeOemConfig: true,
      includeEquipmentStatus: true,
      includeNotificationSettings: true,
      includeVersion: true,
      includeSensors: true
    }

    attr_accessor :client
    attr_reader :index, :max_index, :orig_response

    def initialize(
      client: nil,
      index: 0,
      selection: nil,
      selection_args: {},
      token: nil,
      to_sym: true
    )
      @client = client || Ecobee::Client.new(token: token)
      @to_sym = to_sym
      @index = index
      @selection ||= Ecobee::Selection(
        DEFAULT_SELECTION_ARGS.merge(selection_args)
      )
      refresh
    end

    def cool_range(with_delta: false)
      if with_delta
        low_range = [@orig_response['settings']['coolRangeLow'] / 10,
                     desired_heat + heat_cool_min_delta].max
      else
        low_range = @orig_response['settings']['coolRangeLow'] / 10
      end
      (low_range..@orig_response['settings']['coolRangeHigh'] / 10)
    end

    def heat_cool_min_delta
      @orig_response['settings']['heatCoolMinDelta'] / 10
    end

    def desired_cool
      @orig_response['runtime']['desiredCool'] / 10
    end

    def desired_cool=(temp)
      set_hold_temp(cool_hold_temp: temp * 10)
    end

    def desired_heat
      @orig_response['runtime']['desiredHeat'] / 10
    end

    def desired_heat=(temp)
      set_hold_temp(heat_hold_temp: temp * 10)
    end

    def desired_range
      (desired_heat..desired_cool)
    end

    def heat_range(with_delta: false)
      if with_delta
        high_range = [@orig_response['settings']['heatRangeHigh'] / 10,
                     desired_cool - heat_cool_min_delta].min
      else
        high_range = @orig_response['settings']['heatRangeHigh'] / 10
      end
      (@orig_response['settings']['heatRangeLow'] / 10..high_range)
    end

    def mode
      @orig_response['settings']['hvacMode']
    end

    def mode=(mode)
      set_mode(mode)
    end

    def model
      Ecobee::Model(@orig_response['modelNumber'])
    end

    def my_selection
      { 
        'selection' => {
          'selectionType' => 'thermostats',
          'selectionMatch' => @orig_response['identifier']
        }
      }
    end

    def refresh
      response = @client.get(:thermostat, @selection)
      if index + 1 > response['thermostatList'].length
        raise ThermostatError.new('No such thermostat')
      end
      @max_index = response['thermostatList'].length - 1
      @orig_response = response['thermostatList'][@index]
 
      self.replace(@to_sym ? to_sym(@orig_response) : @orig_response)
    end 

    def humidity
      @orig_response['runtime']['actualHumidity']
    end

    def temperature
      @orig_response['runtime']['actualTemperature'] / 10.0
    end

    def to_sym?
      @to_sym
    end

    def to_sym(obj = self)
      if obj.is_a? Hash
        Hash[obj.map do |key, val|
              if key.is_a? String
                [key.to_sym, to_sym(val)]
              else
                [key, to_sym(val)]
              end
            end]
      elsif obj.is_a? Array
        obj.map { |item| to_sym(item) }
      else
        obj
      end
    end

    def set_hold_temp(
      cool_hold_temp: @orig_response['runtime']['desiredCool'],
      heat_hold_temp: @orig_response['runtime']['desiredHeat'],
      hold_type: 'nextTransition'
    )
      update(functions: [{ 'type' => 'setHold',
                           'params' => {
                             'holdType' => 'nextTransition',
                             'coolHoldTemp' => cool_hold_temp,
                             'heatHoldTemp' => heat_hold_temp } }])
    end

    def set_mode(mode)
      update(thermostat: { 'settings' => { 'hvacMode' => mode } })
    end

    def update(
      functions: nil,
      thermostat: nil
    )
      body = my_selection
      body.merge!({ 'functions' => functions }) if functions
      body.merge!({ 'thermostat' => thermostat }) if thermostat
      @client.post(:thermostat, body: body)
    end

  end
end
