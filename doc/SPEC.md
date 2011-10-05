GhostReader/Writer protocol (initial draft)
===========================================

# Purpose

The ghost/writer communication protocol should define the process for
efficient exchange of the missing i18n translations from the reader and
completed translations from the writer.

# Specification

## Prerequisites

* The client/server communication should use HTTPS
* The communication should use JSON for exchanging data
* Identification should be performed by use of an API key
* Authentication/Authorization are not yet addressed

## Use cases

* There are no requests specific to a locale. All request will update
  or return translations for multiple locales.
* I18n keys may occur in two different forms:
  - aggregated (string), e.g. `"this.is.a.sample.key"`
  - nested (hash), e.g. (in JSON) `{"this":{"is":{"a":{"sample":{"key":null}}}}}`

### Application start (initial request)

* On application start a request should be made from server to send the
  already completed translations
  - Use rails caching for case when multiple instances of the application are started
  - This request has to be nonlocking/async, and must not hang or
    crash the server if it fails
  - The server performs caching on this request. (Note: Because of
    different output formats it might make sense to caching on object
    level.)
  - The server must set the "Last-Modified" HTTP header.
  - Request scheme: (1) `GET https://ghostwriter/api/<APIKEY>/translations`
  - The client will track the "Last-Modified" time for use in
    'incremental requests'.
  - This request will also respond to YAML & CSV for exporting.

### Client reports missing translations (reporting request)

* The client should gather a collection of all missing translations.
  - If a translation is missing the lookup will cascade into other
    sources (I18n backends, like YAML files). (Note: This cannot be
    achieved by chaining backends since fallbacks will not be
    propagated.)
  - If the lookup yields a result the result will reported along with
    the key as a default value.

* The client should POST data for the missing translations.
  - the server must respond with a Redirect-After-Post redirecting to (1)
  - Request scheme: (2) `POST https://ghostwriter/api/<APIKEY>/translations`

* The server will validate the keys and create or update untranslated
  entries.

### Client recieves updated translations (incremental request)

* The client should GET data for updated translations
  - The client must set the "If-Modified-Since" HTTP header. (Otherwise
    the request equals the inital GET and all of the translations are sent.)
  - The server will only send the transaltions that where updated
    between the potint in time denoted by the "If-Modified-Since"
    header and the time of the request (now).
  - The server will set the "Last-Modified" HTTP header.
  - The server will NOT perform any caching.
  - Request scheme: (3) `GET https://ghostwriter/api/<APIKEY>/translations`,
    with "If-Modified-Since" HTTP header set
* The client will merge the recieved data into it's current pool of
  translations.
  - Thereby the client will overwrite any conflicting translations
    with the newly recieved data.
* The client will track the "Last-Modified" header for future requests.

### Error handling

* The client should log the error and retry the request.
* After a number of retries the client should inform the administrator
  (through email, sms... etc.) that there is a problem.

## Data model definition

### Request

* The request data should contain the following:
  - locale code
  - the i18n keys (aggregated) which where requested but have no
    translation
  - the default values if fallback lookups yielded a result
  - a count, indicating how often they were requested (can be used
    as a proxy variable for importance)
  - timestamp when the last request was made
    (as HTTP header "Last-Modified" -> "If-Modified-Since")
* Sample Request, reporting missing (JSON)

```
{"sample.key_1":{"en":{"count":42,"default":"Sample translation 1."}},
"sample.key_2":{"en":{"count":23,"default":"Sample translation 2."}}}
```

### Response

* The response data should contain the following
  - keys (nested) and their translations, nested in locales
  - timestamp, when response was made ("Last-Modifed" HTTP header)
* Sample Response (JSON)

```
{"en":{"sample":{"key_1":"Sample translation 1.","key_2":"Sample translation 2."}}}
```

# Addendum

## HTTP header date formats are specified here

* http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.3
* http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.29
* e.g. in ruby strftime format '%a, %d %b %Y %H:%M:%S %Z'
