# LucaBook

LucaBook is Accounting book kepping application.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'lucabook'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install lucabook

## Usage

TODO: Write usage instructions here


## Journal format

Accounting requires full scan on journals. LucaBook journal format gathers code & amount matrix in the first part of file for efficiency. 

* Base coding is Tab separated value(TSV) text file, encoded with UTF-8.
* Like HTTP, each file consists of header and body, separated empty row. Header is used for calculation, and body is for human readable doc.
* First 4 rows are required header, defined as bellows:
    1. debit code list
    2. debit amount list. Each column corresponds to the debit code above.
    3. credit code list
    4. credit amount list. Each column corresponds to the credit code above.
* After 5th row is for optional header. First column is header label, second column is for its value.
    * x-editor
    * x-company
* Body is now referred as note, not used for any functionality.


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/chumaltd/luca .
