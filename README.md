# LucaSuite

## What's LucaSuite

LucaSuite is work-in-progress ERP applications, named after [Luca Pacioli](https://en.wikipedia.org/wiki/Luca_Pacioli)(1447 - 1517).

* LucaBook: Accounting
* LucaDeal: Sales contract management
* LucaSalary: Salary calculation


## Framework

LucaSuite is built on top of framework like LucaRecord.

* Git aware: App data can be stored in git repository. DBMS free.
* CLI intensive: Flexible integration with various CI tools.
* Extensible: Configurable importer, domain specific extensions.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'lucasuite'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install luca

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/chumaltd/luca .
