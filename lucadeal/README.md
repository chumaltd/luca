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


## Data Structure

Records are stored in YAML format. On historical records, see [LucaRecord](../lucarecord/README.md#historical-field).

### Customer

Customer consists of label information.

| Top level | Second level |      | historical | Description                    |
|-----------|--------------|------|------------|--------------------------------|
| id        |              | auto |            | uuid                           |
| name      |              | must | x          | customer's name                |
| address   |              |      | x          |                                |
| address2  |              |      | x          |                                |
| contacts  |              |      |            | Array of contact information   |
|           | mail         |      |            | mail address receiving invoice |


### Contract

Contract is core object for calculation. Common fields are as follows:

| Top level   | Second level  |          | historical | Description                                                                                          |
|-------------|---------------|----------|------------|------------------------------------------------------------------------------------------------------|
| id          |               | auto     |            | uuid                                                                                                 |
| customer_id |               | must     | x          | customer's uuid                                                                                      |
| terms       |               |          |            |                                                                                                      |
|             | effective     | must     |            | Start date of the contract.                                                                          |
|             | defunct       |          |            | End date of the contract.                                                                            |

Fields for subscription customers are as bellows:

| Top level | Second level  |          | historical | Description                                                                                          |
|-----------|---------------|----------|------------|------------------------------------------------------------------------------------------------------|
| terms     |               |          |            |                                                                                                      |
|           | billing_cycle | optional |            | If 'monthly', invoices are generated on each month.                                                  |
|           | category      | optional |            | Default: 'subscription'                                                                              |
| items     |               |          |            | Array of items.                                                                                      |
|           | name          |          | x          | Item name.                                                                                           |
|           | price         |          | x          | Item price.                                                                                          |
|           | qty           | optional | x          | quantity. Default: 1.                                                                                |
|           | type          | optional |            | If 'initial', this item is treated as initial cost, applied only on the first month of the contract. |
| sales_fee |               | optional |            |                                                                                                      |
|           | id            |          |            | contract id of fee with sales partner.                                                               |


Fields for sales fee are as bellows:

| Top level | Second level |          | historical | Description                                                                         |
|-----------|--------------|----------|------------|-------------------------------------------------------------------------------------|
| terms     |              |          |            |                                                                                     |
|           | category     |          |            | If 'sales_fee', contract is treated as selling commission. |
| rate      |              | optional |            |                                                                                     |
|           | default      |          |            | sales fee rate.                                                                     |
|           | initial      |          |            | sales fee rate for items of type=initial.                                           |


### Invoice

Invoice is basically auto generated from Customer and Contract objects.

| Top level  | Second level | Description                              |
|------------|--------------|------------------------------------------|
| id         |              | uuid                                     |
| issue_date |              |                                          |
| due_date   |              |                                          |
| customer   |              |                                          |
|            | id           | customer's uuid                          |
|            | name         | customer name                            |
|            | address      |                                          |
|            | address2     |                                          |
|            | to           | Array of mail addresses                  |
| items      |              | Array of items.                          |
|            | name         | Item name.                               |
|            | price        | Item price.                              |
|            | qty          | quantity. Default: 1.                    |
|            | type         |                                          |
| subtotal   |              | Array of subtotal by tax category.       |
|            | items        | amount of items                          |
|            | tax          | amount of tax                            |
|            | rate         | applied tax category. Default: 'default' |
| sales_fee  |              |                                          |
|            | id           | contract id of fee with sales partner.   |
| status     |              | Array of status with timestamp.          |


### Fee

Fee is basically auto generated from Contract and Invoice objects.

| Top level | Second level | Description                                  |
|-----------|--------------|----------------------------------------------|
| id        |              | uuid                                         |
| sales_fee |              |                                              |
|           | id           | contract id with sales partner.              |
|           | default.fee  | Amount of fee on dafault rate.               |
|           | default.tax  | Amount of tax for default.fee.               |
|           | initial.fee  | Amount of fee on initial cost.               |
|           | initial.tax  | Amount of tax for initial.fee.               |
| invoice   |              | Carbon copy of Invoice attributes.           |
|           | id           |                                              |
|           | contract_id  |                                              |
|           | issue_date   |                                              |
|           | due_date     |                                              |
| customer  |              | Carbon copy of Invoice customer except 'to'. |
| items     |              | Carbon copy of Invoice items.                |
| subtotal  |              | Carbon copy of Invoice subtotal.             |
| status    |              | Array of status with timestamp.              |


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/chumaltd/luca .
