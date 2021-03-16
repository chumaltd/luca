## LucaRecord master

* @record_type = 'raw' is deprecated in favor of overriding LucaRecord::IO.load_data
* change code search from exact match to prefix match

## LucaRecord 0.2.27

* Fix: update_digest

## LucaRecord 0.2.26

* Support #dig / #search for TSV dictionary
* Fix: shorten n-gram split factor on search word length < specified factor

## LucaRecord 0.2.25

* Implement `dir_digest()` for data validation.
* support defunct without effective history record

## LucaRecord 0.2.24

* Digit delimiter for `delimit_num` can be customized through `thousands_separator` and `decimal_separator` in config.yml.
* Const `CONFIG` and `PJDIR` is defined at `LucaRecord::Base`.
* add `LucaSupport::Code.keys_stringify()`

## LucaRecord 0.2.23

* Enhance Dictionary, supporting extensible options.

## LucaRecord 0.2.22

* add `LucaSupport::View.nushell()`, render nushell table directly.

## LucaRecord 0.2.21

* Enhance `LucaSupport::Code.delimit_num()`. Handle with BigDecimal, decimal length & delmiter customization.

## LucaRecord 0.2.20

* UUID completion framework on prefix match

## LucaRecord 0.2.19

* `LucaSupport::Code.decode_id()`
* `LucaSupport::Code.encode_term()` for multiple months search. Old `scan_term()` removed.

## LucaRecord 0.2.18

* `find()`, `create()`, `save()` now supports both of uuid / historical records. If specified `date:` keyword option to `create()`, then generate historical record. `find()`, `save()` identifies with 'id' attribute.

## LucaRecord 0.2.17

* Change internal number format to BigDecimal.
* Number of Decimal is configurable through `decimal_number` in config.yml(default = 2). `country` setting can also affect.
