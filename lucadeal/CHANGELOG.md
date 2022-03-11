## LucaDeal 0.3.1

* add `luca-deal invoices settle --search-terms` for late payment case.

## LucaDeal 0.3.0

* implement `luca-deal reports balance` for unsettled balance by customer
* implement `luca-deal invoices settle` for import payment data from LucaBook

## LucaDeal 0.2.25

* implement deduction rate for fee calculation.
* implement `luca-deal fee export`
* refine export label for luca-book compatibility
* add `luca-deal invoice create --monthly --with-fee` option.
* preview_mail can deliver regardless of `mail_delivered` status
* `luca-deal fee mail` skip no item record by default.

## LucaDeal 0.2.24

* add `luca-deal invoices create --monthly --mail`, send payment list after monthly invoice creation.
* add 'other_payments' tracking with no invoices.
* can have limit on fee calculation.
* initial implment of `luca-deal fee list`

## LucaDeal 0.2.23

* implement `luca-deal invoices list --mail`: payment list via HTML mail

## LucaDeal 0.2.22

* Breaking change: export key 'value' -> 'amount'

## LucaDeal 0.2.21

* Implement `luca-deal fee` subcommands.
* single invoice creation with contract id fragment.

## LucaDeal 0.2.20

* CLI provides `--nu` option. Add JSON output.
* `luca-deal invoices list --html`, rendering HTML to stdout.

## LucaDeal 0.2.19

* CLI id completion on Customer delete, Contract create/delete
* add `describe` to Customer / Contract

## LucaDeal 0.2.18

* Breaking change: restructure CLI in sub-sub command format.
* Add 'x-customer', 'x-editor' on export to LucaBook

## LucaDeal 0.2.17

* `luca-deal export` export JSON for LucaBook

## LucaDeal 0.2.14

* Introduce Product for selling items template.

## LucaDeal 0.2.12

* Introduce Sales fee calculation.

## LucaDeal 0.2.10

* items can have one time cost at initial month of contract.
