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
