## LucaBook 0.2.13

* Replace CLI `luca-book list [--code CODE] year month [year month]` with new `LucaBook::List` class. Output YAML for [nu-shell](https://www.nushell.sh/) integration. On Nu, `luca-book list ... | from yaml` shows table format.

## LucaBook 0.2.12

* Journal internally codes currency value as BigDecimal
* `update_codes()` for refreshing index.
