# Ecobee

Ecobee API Ruby Gem.  Implements: 
- OAuth PIN-based token registration & renewal
- Persistent HTTP connection
- Methods for get & push requests
- Persistent storage for API key & refresh tokens
- Example usage scripts (see /examples/\*)

TODO:
- Add timeout to Ecobee::Token#wait
- Convert storage to optional block/proc
- Implement throttling / blocking (?)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ecobee'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ecobee

## Usage

Obtain an Application Key from Ecobee by [registering your project](https://www.ecobee.com/developers).

Using Ecobee::Token, obtain an OAuth Access Token
- Instantiate Ecobee::Token with the api_key and desired scope
- Give user Ecobee::Token#pin and instructions to register your Application via the [Ecobee My Apps Portal](https://www.ecobee.com/consumerportal/index.html#/my-apps)
- You can call Ecobee::Token#wait to block until the user confirms the PIN code.

Instantiate Ecobee::Client with the token object.

Call Ecobee::Client#get or Ecobee::Client#push to interact with [Ecobee's API](https://www.ecobee.com/home/developer/api/introduction/index.shtml)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/robzr/ecobee.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

