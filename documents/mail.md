Luca::Mail
=========

Email sending utility class via SMTP.
Setup sending host from config.

### Config

Mail settings are configurable under `mail` section.

| Top level | Second level        |          | Description                        |
|-----------|---------------------|----------|------------------------------------|
| mail      |                     |          |                                    |
|           | address             | must     | SMTP host                          |
|           | port                | optional | SMTP port                          |
|           | domain              | optional | Sender host                        |
|           | ssl                 | bool     |                                    |
|           | tls                 | bool     |                                    |
|           | openssl_verify_mode | optional | host verification using OpenSSL    |
|           | from                |          |                                    |
|           | cc                  |          |                                    |
|           | ca_file             | optional | CA root file for host verification |
|           | client_cert         | optional | Client Certificate for mTLS        |
|           | client_key          | optional | Private key for mTLS               |


### implementations

* LucaTrade
    * https://github.com/chumaltd/luca-trade/blob/master/lib/luca_trade/invoice.rb
    * send invoice functionality with attachment.
* LucaSalary
    * https://github.com/chumaltd/luca-salary/blob/master/lib/luca/salary/monthly.rb
    * send text report
