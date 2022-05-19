# LucaSuite

[![Gem Version](https://badge.fury.io/rb/lucasuite.svg)](https://badge.fury.io/rb/lucasuite)
![license](https://img.shields.io/github/license/chumaltd/luca)

## What's LucaSuite

LucaSuite is work-in-progress ERP applications, named after [Luca Pacioli](https://en.wikipedia.org/wiki/Luca_Pacioli)(1447 - 1517).  
Built on Ruby, its primary target is terminal environment for Linux, Android [Termux](https://termux.com/), Mac.

* [LucaBook](lucabook/README.md): Accounting
* [LucaDeal](lucadeal/README.md): Sales contract management
* [LucaSalary](lucasalary/README.md): Salary calculation
* [LucaTerm](lucaterm/README.md): Interactive terminal client based on ncurses. This needs to be installed separately.


## Framework

LucaSuite is built on top of framework like [LucaRecord](lucarecord/README.md).

* Git aware: App data can be stored in git repository. DBMS free.
* Minimal: Written with Ruby standard library at its core.
* CLI intensive: Flexible integration with various CI tools.
* Historical API: Notation for changing attributes.
* Accurate: BigDecimal codec at load/save.
* Extensible: Configurable importer, domain specific extensions.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'lucasuite'
gem 'mail'         # If you don't use mail functionality, you can remove this line.
# gem 'lucaterm'   # If you need TUI client, enable this line.
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install lucasuite

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/chumaltd/luca .
