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

## Use cases

### Application start

* On application start a request should be made from server to send the
complete translations

### Client requests data for missing translations

* The client should gather a collection of all missing translations
* The client should POST data for the missing translations
  - the server should respond with the newest completed translations
  - the server should set IF-MODIFIED flag
  - the server should cache the last response
  - if the translations are not changed since IF_MODIFIED was set, the
server should send the cached data

### Client receives data with completed translations

* The building of the YAML file should happen on the client side

### Client sends all translated data to server

* The server should validate the data and update the untranslated entries

### Client receives error message

* The client should log the error and retry the request
* After a number of retries the client should notify the administrator
(through email, sms... etc) that there is a problem

## Data model definition

### Request

* The request data should contain the following
  - locale name
  - the i18n keys which have no translation
  - timestamp when request was made

### Response

* The response data should contain the following
  - the completed translations only for the requested locale and
translation keys in JSON format
  - timestamp when response was made
