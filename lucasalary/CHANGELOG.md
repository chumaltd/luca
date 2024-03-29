## LucaSalary 0.6.1

* Reworked global constants w/LucaRecord v0.7
* Removed bundler from test suite avoiding casual native build
* add `luca-salary version` subcommand

## LucaSalary 0.6.0

* BREAKING: monthly payment now passes calculation date to local modules.
* BREAKING: year total calculation now passes profiles to local modules.

## LucaSalary 0.5.0

* `luca-salary` command now searches valid sub directory.

## LucaSalary 0.1.29

* `luca-salary payment list` supports interactive `--explore` w/nushell.

## LucaSalary 0.1.28

* BREAKING: `luca-salary payments total` directory structure changed. Upsert 1 record per 1 profile.
* move yearly totale methods to LucaSalary::Total
* add `luca-salary pay[ments]` short hand.
* add `luca-salary payments list --nu`.

## LucaSalary 0.1.27

* Implement LucaSalary::Total for Year totaling.

## LucaSalary 0.1.26

* Add `luca-salary payments report`: monthly statement by code.

## LucaSalary 0.1.25

* Add `luca-salary payments total --adjust`: applying yearly tax refund.

## LucaSalary 0.1.24

* Fix: remove null record from `luca-salary export` JSON

## LucaSalary 0.1.23

* Breaking change: move sum_code() to Class method

## LucaSalary 0.1.22

* Add `luca-salary payments total` command for year total
* Fix: call localcode with calculation date

## LucaSalary 0.1.20

* Implement `year_total`
* Breaking change: export key 'value' -> 'amount'

## LucaSalary 0.1.19

* Support `payment_term` on config.yml for accounting export.

## LucaSalary 0.1.18

* Add summary to payslip. Refactor monthly payment.

## LucaSalary 0.1.17

* Breaking change: restructure CLI in sub-sub command format.
* Add 'x-editor' on export to LucaBook
