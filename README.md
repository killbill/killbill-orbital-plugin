killbill-orbital-plugin
=======================

Plugin to use [Orbital](http://www.chasepaymentech.com/payment_gateway.html) as a gateway.

Release builds are available on [Maven Central](http://search.maven.org/#search%7Cga%7C1%7Cg%3A%22org.kill-bill.billing.plugin.ruby%22%20AND%20a%3A%22orbital-plugin%22) with coordinates `org.kill-bill.billing.plugin.ruby:orbital-plugin`.

Kill Bill compatibility
-----------------------

| Plugin version | Kill Bill version |
| -------------: | ----------------: |
| 0.0.x          | 0.16.z            |
| 0.1.x          | 0.18.z            |

Requirements
------------

The plugin needs a database. The latest version of the schema can be found [here](https://github.com/killbill/killbill-orbital-plugin/blob/master/db/ddl.sql). 
Regarding the VISA MIT/CIT parameters in the request, it is the client or the control plugin's responsibility to decides if these parameters should be passed on VISA cards only or not. The plugin will send the parameters to Orbital regardless of the card type.

Configuration
-------------

```
curl -v \
     -X POST \
     -u admin:password \
     -H 'X-Killbill-ApiKey: bob' \
     -H 'X-Killbill-ApiSecret: lazar' \
     -H 'X-Killbill-CreatedBy: admin' \
     -H 'Content-Type: text/plain' \
     -d ':orbital:
  - :account_id: "merchant_account_1"
    :login: "your-login"
    :password: "your-password"
    :merchant_id: "your-merchant-id"
  - :account_id: "merchant_account_2"
    :login: "your-login"
    :password: "your-password"
    :merchant_id: "your-merchant-id"' \
     http://127.0.0.1:8080/1.0/kb/tenants/uploadPluginConfig/killbill-orbital
```

To go to production, create a `orbital.yml` configuration file under `/var/tmp/bundles/plugins/ruby/killbill-orbital/x.y.z/` containing the following:

```
:orbital:
  :test: false
```

Usage
-----

To store a credit card:

```
curl -v \
     -X POST \
     -u admin:password \
     -H 'X-Killbill-ApiKey: bob' \
     -H 'X-Killbill-ApiSecret: lazar' \
     -H 'X-Killbill-CreatedBy: admin' \
     -H 'Content-Type: application/json' \
     -d '{
       "pluginName": "killbill-orbital",
       "pluginInfo": {
         "properties": [
           {
             "key": "ccFirstName",
             "value": "John"
           },
           {
             "key": "ccLastName",
             "value": "Doe"
           },
           {
             "key": "address1",
             "value": "5th Street"
           },
           {
             "key": "city",
             "value": "San Francisco"
           },
           {
             "key": "zip",
             "value": "94111"
           },
           {
             "key": "state",
             "value": "CA"
           },
           {
             "key": "country",
             "value": "USA"
           },
           {
             "key": "ccExpirationMonth",
             "value": 12
           },
           {
             "key": "ccExpirationYear",
             "value": 2017
           },
           {
             "key": "ccNumber",
             "value": "4111111111111111"
           }
         ]
       }
     }' \
     "http://127.0.0.1:8080/1.0/kb/accounts/<ACCOUNT_ID>/paymentMethods?isDefault=true"
```

To trigger a payment:

```
curl -v \
     -X POST \
     -u admin:password \
     -H 'X-Killbill-ApiKey: bob' \
     -H 'X-Killbill-ApiSecret: lazar' \
     -H 'X-Killbill-CreatedBy: admin' \
     -H 'Content-Type: application/json' \
     -d '{
       "transactionType": "AUTHORIZE",
       "amount": 5
     }' \
     http://127.0.0.1:8080/1.0/kb/accounts/<ACCOUNT_ID>/payments
```

Plugin properties
-----------------

| Key                          | Description                                                       |
| ---------------------------: | ----------------------------------------------------------------- |
| skip_gw                      | If true, skip the call to Orbital                                 |
| payment_processor_account_id | Config entry name of the merchant account to use                  |
| external_key_as_order_id     | If true, set the payment external key as the Orbital order id     |
| cc_first_name                | Credit card holder first name                                     |
| cc_last_name                 | Credit card holder last name                                      |
| cc_type                      | Credit card brand                                                 |
| cc_expiration_month          | Credit card expiration month                                      |
| cc_expiration_year           | Credit card expiration year                                       |
| cc_verification_value        | CVC/CVV/CVN                                                       |
| cvv_indicator_visa_discover  | If true, set '9' as `CardSecValInd` when CVV is absent (Visa / Discover only ) |
| cvv_indicator_override_visa_discover | `CardSecValInd` value when CVV is absent (Visa / Discover only) |
| email                        | Purchaser email                                                   |
| address1                     | Billing address first line                                        |
| address2                     | Billing address second line                                       |
| city                         | Billing address city                                              |
| zip                          | Billing address zip code                                          |
| state                        | Billing address state                                             |
| country                      | Billing address country                                           |
| eci                          | Network tokenization attribute                                    |
| payment_cryptogram           | Network tokenization attribute                                    |
| transaction_id               | Network tokenization attribute                                    |
| payment_instrument_name      | ApplePay tokenization attribute                                   |
| payment_network              | ApplePay tokenization attribute                                   |
| transaction_identifier       | ApplePay tokenization attribute                                   |
| order_id                     | Orbital order id                                                  |
| trace_number                 | Trace number used for inquiry transaction information             |
| credential_on_file           | Indicates that the cardholder’s credentials are on-file with the merchant or not. |
| mit_cit_type                 | Indicates the message type to be used for the message type records |
| mit_ref_trx_id               | Kill Bill transaction ID used to locate the Transaction Reference Number returned in the corresponding CIT transaction.| 