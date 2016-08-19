# Ecobee

Ecobee API Ruby Gem.  Implements: 
- OAuth PIN-based token registration & renewal
- Persistent HTTP connection management
- Methods for GET & POST requests w/ JSON parsing & error handling
- Persistent storage for API key & refresh tokens
- Storage uses iCloud Drive if available for shared computer use
- Block/Proc hooks for token storage load/save to add app config data
- Thermostat abstraction class for simple thermostat interaction
- Example usage scripts (see /examples/\*)

TODO:
- Add RDoc documentation
- Add redirect based registration

## Installation

The latest ecobee Ruby Gem is [available from Rubygems.org](https://rubygems.org/gems/ecobee).

To install from the command line, run:
```
gem install ecobee
```

## Usage

1. Obtain an Application Key from Ecobee by [registering your project](https://www.ecobee.com/developers).

2. Using Ecobee::Token, obtain an OAuth Access Token.
  - Instantiate Ecobee::Token with the api_key and desired scope.
  - Give user Ecobee::Token#pin and instructions to register your Application via the [Ecobee My Apps Portal](https://www.ecobee.com/consumerportal/index.html#/my-apps).
  - You can call Ecobee::Token#wait to block until the user confirms the PIN code.

3. Instantiate Ecobee::Thermostat with the token object.

4. Use the simplified methods for common interactions, access the Thermostat object directly as a Hash to read values, or use the update method to post changes.

5. Ecobee::Client#get or Ecobee::Client#post can be used for advanced interaction with [Ecobee's API](https://www.ecobee.com/home/developer/api/introduction/index.shtml).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/robzr/ecobee.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

