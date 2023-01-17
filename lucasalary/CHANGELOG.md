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
