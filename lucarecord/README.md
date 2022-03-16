# LucaRecord

[![Gem Version](https://badge.fury.io/rb/lucarecord.svg)](https://badge.fury.io/rb/lucarecord)
[![doc](ihttps://img.shields.io/badge/doc-rubydoc-green.svg)](https://www.rubydoc.info/gems/lucarecord/index)

LucaRecord is Git-aware ERP app framework.

## Historical Field

LucaRecord supports historically changing field. Attributes of ERP data often change. For instance, `price` as bellows is always 300.

```yaml
price: 300
```

Historical field can be defined with `effective` and `val` keywords, too. `price` will get 500 asof after 2020/10/1. Actual value is determined on search date.

```yaml
price:
- effective: 2020-10-1
  val: 500
- effective: 2020-8-1
  val: 300
```

And, `defunct` key terminates scope of `val`. `price` will be nil before 2020-7-31 and after 2021-1-1.

```yaml
price:
- effective: 2020-10-1
  defunct: 2020-12-31
  val: 500
- effective: 2020-8-1
  val: 300
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/chumaltd/luca .
