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

    attr_reader :auto_refresh, :http

    def initialize(
      auto_refresh: 0,
      fake_index: nil,
      index: 0,
      fake_max_index: 0,
      selection: nil,
      selection_args: {},
      token: nil
    )
      # TODO: add auto-refresh thread handling
      @auto_refresh = auto_refresh

      raise ArgumentError.new('No token: specified') unless token
      @http = token.http
      @fake_index = fake_index
      @fake_max_index = fake_max_index
      @index = index
      @selection ||= Ecobee::Selection(
        DEFAULT_SELECTION_ARGS.merge(selection_args)
      )
      refresh
    end

    def celsius?
      self[:settings][:useCelsius]
    end

    def cool_range(with_delta: false)
      if with_delta
        low_range = [unitize(self[:settings][:coolRangeLow]),
                     desired_heat + heat_cool_min_delta].max
      else
        low_range = unitize(self[:settings][:coolRangeLow])
      end
      to_range(low_range, unitize(self[:settings][:coolRangeHigh]))
    end

    def dump(pretty: true)
      if pretty
        self.select { |k, v| k.is_a? Symbol }.pretty_inspect
      else
        self.select { |k, v| k.is_a? Symbol }
      end
    end

    def desired_cool
      unitize(self[:runtime][:desiredCool])
    end

    def desired_cool=(temp)
      set_hold(cool_hold_temp: temp)
    end

    def desired_fan_mode
      self[:runtime][:desiredFanMode]
    end

    def desired_fan_mode=(fan)
      set_hold(fan: fan)
    end

    def desired_heat
      unitize(self[:runtime][:desiredHeat])
    end

    def desired_heat=(temp)
      # need celcius un_unitize
      set_hold(heat_hold_temp: temp)
    end

    def desired_range
      to_range(desired_heat, desired_cool)
    end

    def heat_cool_min_delta
      unitize(self[:settings][:heatCoolMinDelta])
    end

    def heat_range(with_delta: false)
      if with_delta
        high_range = [unitize(self[:settings][:heatRangeHigh]),
                     desired_cool - heat_cool_min_delta].min
      else
        high_range = unitize(self[:settings][:heatRangeHigh])
      end
      to_range(unitize(self[:settings][:heatRangeLow]), high_range)
    end

    def humidity
      self[:runtime][:actualHumidity]
    end

    def index
      @fake_index || @index
    end

    def max_index
      [@fake_index || 0, @max_index, @fake_max_index].max
    end

    def mode
      self[:settings][:hvacMode]
    end

    def mode=(mode)
      set_mode(mode)
    end

    def model
      Ecobee::Model(self[:modelNumber])
    end

    def my_selection
      { 
        'selection' => {
          'selectionType' => 'thermostats',
          'selectionMatch' => self[:identifier]
        }
      }
    end

    def name
      if @fake_index
        "Fake No. #{@fake_index}"
      else
        self[:name]
      end
    end

    def refresh
      response = @http.get(arg: :thermostat, options: @selection)
      if @index + 1 > response['thermostatList'].length
        raise ThermostatError.new('No such thermostat')
      end
      @max_index = response['thermostatList'].length - 1
      list = response['thermostatList'][@index]
 
      self.replace list.merge(to_sym(list))
    end 

    def set_hold(
      cool_hold_temp: unitize(self[:runtime][:desiredCool]),
      fan: nil,
      heat_hold_temp: unitize(self[:runtime][:desiredHeat]),
      hold_type: 'nextTransition'
    )
      params = { 
        'holdType' => 'nextTransition',
        'coolHoldTemp' => un_unitize(cool_hold_temp),
        'heatHoldTemp' => un_unitize(heat_hold_temp)
      }
      params.merge!({ 'fan' => fan }) if fan
      update(functions: [{ 'type' => 'setHold', 'params' => params }])
    end

    def set_mode(mode)
      update(thermostat: { 'settings' => { 'hvacMode' => mode } })
    end

    def temperature
      unitize(self[:runtime][:actualTemperature])
    end

    def to_range(low, high)
      if celsius?
        ((low * 2).round..(high * 2).round).to_a
          .map { |deg| deg / 2.0 }
      else
        (low.round..high.round).to_a
      end
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

    def un_unitize(value)
      if celsius?
        (((value.to_f * 9/5) + 32) * 10).round
      else
        (value.to_f * 10).round
      end
    end

    # converts Ecobee farenheit * 10 integer input, returns 
    #  farenheit or celsius output rounded to nearest .5
    def unitize(value)
      if celsius?
        celsius = (value.to_f / 10.0 - 32) * 5/9
        (celsius / 5).round(1) * 5
      else
        value.to_f / 10.0
      end
    end

    def update(
      functions: nil,
      thermostat: nil
    )
      body = my_selection
      body.merge!({ 'functions' => functions }) if functions
      body.merge!({ 'thermostat' => thermostat }) if thermostat
      @http.post(arg: :thermostat, body: body)
    end

  end

end
