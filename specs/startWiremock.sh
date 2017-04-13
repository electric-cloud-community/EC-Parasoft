#!/usr/bin/env bash

rm -rf __fiiles
rm -rf mappings
java -jar wiremock-standalone-2.6.0.jar --enable-browser-proxying --verbose --record-mappings --port 7887
