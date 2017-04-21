#!/usr/bin/env bash


DIR=$(dirname $0)
export WIREMOCK_DIR=$DIR
echo $WIREMOCK_DIR
$DIR/ec-specs $DIR/test/
