# nbu_currency

## Introduction

This gem downloads the exchange rates from the National Bank Of Ukraine. You can calculate exchange rates with it. It is compatible with the money gem.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'nbu_currency'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install nbu_currency

## Usage

With the gem, you do not need to manually add exchange rates. Calling update_rates will download the rates from the National Bank Of Ukraine. The API is the same as the money gem. Feel free to use Money objects with the bank.

For performance reasons, you may prefer to read from a file instead. Furthermore, NBU publishes their rates daily. It makes sense to save the rates in a file to read from. It also adds an __update_at__ field so that you can manage the update.

``` ruby
# cached location
cache = "/some/file/location/exchange_rates.xml"

# saves the rates in a specified location
nbu_bank.save_rates(cache)

# reads the rates from the specified location
nbu_bank.update_rates(cache)

if !nbu_bank.rates_updated_at || nbu_bank.rates_updated_at < Time.now - 1.days
  nbu_bank.save_rates(cache)
  nbu_bank.update_rates(cache)
end

# exchange 100 CAD to USD as usual
nbu_bank.exchange_with(Money.new(100, "CAD"), "USD") # Money.new(80, "USD")

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/[my-github-username]/nbu_currency/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
