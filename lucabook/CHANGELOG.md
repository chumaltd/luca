## LucaBook master

* Handle starting balance.
* LucaBook::Import append 'x-editor: LucaBook::Import' header.
* provide data/balance/start.tsv template on Setup.

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
