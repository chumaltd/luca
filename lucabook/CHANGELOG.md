## LucaBook 0.5.1

* Abort on counter balance code not found when journal import.
* Reworked global constants w/LucaRecord v0.7
* add `luca-book version` subcommand

## LucaBook 0.5.0

* `luca-book` command now searches valid sub directory.

## LucaBook 0.4.5

* `luca-book journals list|stats` supports interactive `--explore` w/nushell.
* Fix: Empty list on `--nu` option. Column order limited to journal list subcommand.

## LucaBook 0.4.4

* Returns 1 line message on empty results for `luca-book journals list --nu`.
* Fix columns order for `luca-book journals list --nu`.

## LucaBook 0.4.3

* Add prefix for XBRL filename. JP eTax rejects dateonly filename silently.

## LucaBook 0.4.2

* Fix: header validation on import JSON

## LucaBook 0.4.1

* `luca-book reports mail --fy` for Financial Year aware reporting.

## LucaBook 0.4.0

* `Luca::Book::State#net()`, `Luca::Book::State#gross()` can now calcurate with `x-customer` / `x-editor` filter
* `luca-book reports pl|bs --fy` for Financial Year aware reporting.
* `luca-book journals import --json` accepts x-headers

## LucaBook 0.3.0

* `luca-book reports xbrl` supports 'Changes in shareholders equity' generation.
* Add taxonomy list for Japan 'Changes in shareholders equity'.
* `luca-book reports xbrl [--lastyear]` refers financial year config.

## LucaBook 0.2.32

* update JP dictionary for tax accounting automation.

## LucaBook 0.2.31

* Fix: `luca-book journals list --customer` format

## LucaBook 0.2.30

* Implement `luca-book balance export` for M&A
* Fix: set import default code

## LucaBook 0.2.29

* Implement `luca-book journals list [--pdf|--html]` for print

## LucaBook 0.2.28

* Initial implement LucaBook::Test, data testing framework
* implement LucaBook::Util#current_fy, setting range from CONFIG['fy_start']
* Fix: LucaBook::State.net by code now works

## LucaBook 0.2.27

* Support `--recursive` option for `luca-book journals stats -c`, totaling subaccounts.
* Support `--recursive` option for `luca-book journals list -c`, including subaccounts.

## LucaBook 0.2.26

* implement `luca-book balance update`
* select latest balance with given date and fy_start
* support search by account label with `-c` option of `luca-book journals list` and `luca-book journals stats`

## LucaBook 0.2.25

* implement `luca-book report mail`
* implement `luca-book report xbrl`: render XBRL BalanceSheet / IncomeStatement, currently have JP e-tax compatible templates.
* use etax taxonomy dictionary as Japan default

## LucaBook 0.2.24

* add import option, 'x-customer' in YAML settings.
* Add CLI `journals set -c CODE --header x-header --val header-val` for annotation
* Breaking change: import key 'value' -> 'amount'

## LucaBook 0.2.23

* initial implement `luca-book journals list -c --customer`, grouping with x-customer header
* implement `LucaBook::Journal.save()` for updating a record.

## LucaBook 0.2.22

* Import options. Tax extension for each countries.
* Optimize starting balance calculation.

## LucaBook 0.2.21

* Add CLI `-o`, `--output` option, yaml(default) or json.
* Add CLI `--nu` option, show table in nushell.
* Add CLI `journals stats -c CODE` option, show monthly debit/credit amount and journal count.

## LucaBook 0.2.20

* use BigDecimal for statement calculation.
* CLI option for account level(-l, --level) on PL generation

## LucaBook 0.2.19

* config `fy_start` month. BS/PL is calculated on Financial Year basis.

## LucaBook 0.2.18

* CLI generates reports without args
* append date on PL and stats

## LucaBook 0.2.17

* add `luca-book journals stats`
* CLI option for account level(-l, --level) and legal requirement(--legal) on BS generation

## LucaBook 0.2.16

* Handle starting balance.
* XBRL taxonomy for JP EDINET & eTax
* LucaBook::Import append 'x-editor: LucaBook::Import' header.
* provide data/balance/start.tsv template on Setup.
* Refine BS output with legal mandatory accounts.
* Default debit/credit label can be set by each importer. Default unknown code is also set(10XX/50XX).

## LucaBook 0.2.15

* Breaking change: restructure CLI in sub-sub command format.
* Breaking change: import bulk records rather than single record.
* Introduce x-header: 'x-customer', 'x-editor'

## LucaBook 0.2.14

* CLI `luca-book import -j` import via STDIN

## LucaBook 0.2.13

* Replace CLI `luca-book list [--code CODE] year month [year month]` with new `LucaBook::List` class. Output YAML for [nu-shell](https://www.nushell.sh/) integration. On Nu, `luca-book list ... | from yaml` shows table format.

## LucaBook 0.2.12

* Journal internally codes currency value as BigDecimal
* `update_codes()` for refreshing index.
