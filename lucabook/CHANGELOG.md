## LucaBook master

* initial implement `luca-book journals list -c --customer`, grouping with x-customer header

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
