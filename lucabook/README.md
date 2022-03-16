# LucaBook

[![Gem Version](https://badge.fury.io/rb/lucasalary.svg)](https://badge.fury.io/rb/lucabook)
[![doc](ihttps://img.shields.io/badge/doc-rubydoc-green.svg)](https://www.rubydoc.info/gems/lucabook/index)

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

LucaBook works on terminal shell.

CLI subcommand `journals` show journal list. Integrated with Nushell, common reports show in nushell tables with `--nu` option.

```bash
$ luca-book journals list --nu
```

Default list shows the journals of this month. With `-n` option, multiple month can be specified.
If you search for a specific month, args in `YYYY M` format is available. Or, multiple month list is also supported as bellows:

```bash
$ luca-book journals list --nu 2020 3
$ luca-book journals list --nu 2020 3 2020 7
```

Journals of specific accounting code can be filtered with `-c` option. `-c` reports with account balance.

```bash
$ luca-book journals list --nu -c 113
```

Another report is `stats` that shows journal count by accaunt code. This is useful for checking completeness.

```bash
$ luca-book journals stats --nu
```

Stats for specific code is available with `-c` option. `-c` reports debit/credit amount with journal count.

```bash
$ luca-book journals stats --nu -c 113
```

### Report

Balance sheet(BS) and Statement of income(PL) is provided by `reports` subcommand.

```bash
$ luca-book reports bs --nu
$ luca-book reports pl --nu
```


## CSV import

Journals can be generated from CSV like online banking statement. CSV loading is controlled by `dict/import-CONFIG.yaml`([sample config](./test/import-bank1.yaml) and [sample CSV](./test/sample-bankstatement.csv)). Command for import is as bellows:

```
$ luca-book journals import -c bank1 bank-statement.csv
```

This example will import bank-statement.csv with `-c` option for config YAML(dict/import-bank1.yaml).

| Top level   | Second level  | Value                                                     | Description                        |
|-------------|---------------|-----------------------------------------------------------|------------------------------------|
| config      | label         | CSV column no.                                            | label is used for account search   |
|             | counter_label | Account label(string)                                     | like "Saving Account" or bank name |
|             | debit_amount | CSV column no.                                            |                                    |
|             | credit_amount | CSV column no.                                            |                                    |
|             | year          | CSV column no.                                            | year of transaction date.          |
|             | month         | CSV column no.                                            | month of transaction date.         |
|             | day           | CSV column no.                                            | day of transaction date.           |
|             | note          | CSV column no. Multiple columns can be specified as Array | Human readable journal note.       |
| definitions |               | "CSV label": "Accounting label"                           | Convert from CSV label to Accounting code. Accounting label need to be matched exactly as defined in dict/base.tsv. |

CSV label is matched with n-gram, and converted to mostly like account. If no code matched, `10XX/50XX UNSETTLED_IMPORT` will be assigned.

Example setting as bellows will convert CSV record with 'CandSCompany' into 'Account payable - trade'.

```
definitions:
  CandSCompany: "Accounts payable - trade"
```

Advanced option can be available. Array of config with `on_amount` checks transaction amount, and the first is taken that matches specified criteria.

```yaml
definitions:
  CandSCompany:
  - on_amount: ">1000.00"
    account_label: "Accounts payable - trade"
  - account_label: "Accounts payable - other"
```


## JSON import

Journals can be generated from LucaDeal or LucaSalary via JSON import(`-j` option).


## Journal validation test

LucaBook introduced standard testing to book keeping.  
`LucaBook::Test` provides test facilities based on Ruby standard [minitest](https://github.com/seattlerb/minitest).  
You can integrate journal check into CI tools for automation.

```ruby
# frozen_string_literal: true

require 'luca_book/test'

class JournalValidation < LucaBook::Test
  def setup
    # set test range from the start of Financial year to the previous month of today
    current_fy(to: Date.today.prev_month)
  end

  def test_that_has_sales
    # check records in each month
    by_month.each do
      assert net_amount('A11') > 0, "No sales records in #{@cursor_start}"
    end
  end
end
```


## Account code

Account code consists of 2 or more alphanumerical letters of like '1A3'. [Example dictionary](./lib/luca-book/templates/dict-en.tsv) is bundled with gem.

### BS accounts

Codes start from numeric letter are BS accounts.  
Several codes are used for reporting accumulation.

| Code | Sum target | Description                               |
|------|------------|-------------------------------------------|
|    1 | 1 - 4      | Grand total of Assets                     |
|   10 | 1 - 2      | Current assets                            |
|   30 | 3 - 4      | Non current assets                        |
|    5 | 5 - 9      | Grand total of Liabilities and Net assets |
|   50 | 5 - 6      | Current liabilities                       |
|   70 | 7 - 8      | Non current liablities                    |
|  8ZZ | 5 - 8      | Total liabilities                         |
| 9142 |            | Net profit imported from code 'HA'        |
|  9ZZ | 9          | Total net assets                          |

### PL accounts

Codes start from alphabet are PL accounts.  
Several codes are used for reporting accumulation.

| Code | Sum target | Description                         |
|------|------------|-------------------------------------|
| A0   | A          | Revenue                             |
| B0   | B          | Cost of Sales                       |
| BA   |            | Gross Profit                        |
| C0   | C          | General and administrative expenses |
| CA   |            |                                     |
| D0   |            | Non operating income                |
| E0   |            | Non operating expenses              |
| EA   |            |                                     |
| F0   | F          | Extraordinary income                |
| G0   | G[0-9]     | Extraordinary loss                  |
| GA   |            | Income before income taxes          |
| H0   | H          | Income taxes                        |
| HA   |            | Profit/Loss                         |


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
