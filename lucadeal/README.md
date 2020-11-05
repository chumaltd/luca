# LucaDeal

LucaDeal is Sales contract management application.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'lucadeal'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install lucadeal

## Usage

TODO: Write usage instructions here

### Customer

| Top level | Second level |      | Description                    |
|-----------|--------------|------|--------------------------------|
| id        |              | auto | uuid                           |
| name      |              | must | customer's name                |
| address   |              |      |                                |
| address2  |              |      |                                |
| contact   |              |      | Array of contact information   |
|           | mail         |      | mail address receiving invoice |


### Contract

| Top level   | Second level  |          | Description                                                                                          |
|-------------|---------------|----------|------------------------------------------------------------------------------------------------------|
| id          |               | auto     | uuid                                                                                                 |
| customer_id |               | must     | customer's uuid                                                                                      |
| terms       |               |          |                                                                                                      |
|             | effective     | must     |                                                                                                      |
|             | defunct       |          |                                                                                                      |
|             | billing_cycle | optional | If 'monthly', invoices are generated on each month.                                                  |
|             | category      | optional | Default: 'subscription'. If 'sales_fee', contract is treated as selling commission.                  |
| items       |               |          | Array of items.                                                                                      |
|             | name          |          |                                                                                                      |
|             | price         |          |                                                                                                      |
|             | qty           | optional | quantity. Default: 1.                                                                                |
|             | type          | optional | If 'initial', this item is treated as initial cost, applied only on the first month of the contract. |
| rate        |               | optional |                                                                                                      |
|             | default       |          | sales fee rate.                                                                                      |
|             | initial       |          | sales fee rate for items of type=initial.                                                            |

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/luca-deal.
