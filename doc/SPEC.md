GhostReader/Writer protocol (initial draft)
===========================================

# Purpose

The ghost/writer communication protocol should define the process for
efficient exchange of the missing i18n translations from the reader and
completed translations from the writer.

# Specification

## Prerequisites

* The client/server communication should use HTTPS
* The communication should use json format for exchanging data
* Identification should be performed by use of an API key
* Authentication/Authorization are not yet addressed

## Use cases

### Application start (initial request)

* On application start a request should be made from server to send the
  already completed translations

  - This request has to be nonlocking/async, and must not hang or
    crash the server if it fails

  - The server performs caching on this request. (Note: Because of
    different output formats it might make sense to caching on object
    level.)

  - The server must set the "Last-Modified" HTTP header.

  - Request scheme:

    (1) GET https://ghostwriter/api/<APIKEY>/translations

  - The client will track the "Last-Modified" time for use in
    'incremental requests'.

  - This request will also respond to YAML & CSV for exporting.

### Client reports missing translations (reporting request)

* The client should gather a collection of all missing translations.

  - If a translation is missing the lookup will cascade into other
    sources (I18n backends, like YAML files). (Note: This cannot be
    achivied by chaining backends since fallbacks will not be
    propagated.)
  
  - If the lookup yields a result the result will reported along with
    the key as a default value.

* The client should POST data for the missing translations.

  - the server must respond with a Redirect-After-Post redirecting to (1)

  - Request scheme:
  
    (2) POST https://ghostwriter/api/<APIKEY>/translations

Open Question: What happens if one or more of the posted keys are invalid?

### Client recieves updated translations (incremental request)

* The client should GET data for updated translations

  - The client must set the "If-Modified-Since" HTTP header. (Otherwise
    the request equals the inital GET and all of the translations are sent.)
    
  - The server will only send the transaltions that where updated
    between the potint in time denoted by the "If-Modified-Since"
    header and the time of the request (now).

  - The server will set the "Last-Modified" HTTP header.

  - The server will NOT perform any caching.

  - Request scheme:
  
    With "If-Modified-Since" HTTP header set
  
    (3) GET https://ghostwriter/api/<APIKEY>/translations

* The client will merge the recieved data into it's current pool of
  translations.

  - Thereby the client will overwrite any conflicting translations
    with the newly recieved data.
  
* The client will track the "Last-Modified" header for future requests.
  
### Client sends all translated data to server (push request)

* TODO
* The server should validate the data and update the untranslated entries

### Client receives error message

* TODO
* The client should log the error and retry the request
* After a number of retries the client should notify the administrator
(through email, sms... etc) that there is a problem

## Data model definition

* TODO

### Request

* The request data should contain the following

  - locale code
  - the i18n keys which where requested but have no translation
  - the default values if fallback lookups yielded a result
  - a count, indictaing how often they were requested (can be used
    as a proxy variable for importance)
  - timestamp when request was made (what for?)
  - timestamp when the last request was made
    (as HTTP header "Last-Modified" -> "If-Modified-Since")

* Sample JSON

### Response

* The response data should contain the following

  - the completed translations only for the requested locale and
    translation keys in JSON format (only the requested locale?)
  - timestamp when response was made ("Last-Modifed" HTTP header)

* Sample JSON