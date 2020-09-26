#!/bin/bash
cd $(dirname $0)/..
shards build "$1" && exec ./bin/"$1" "${@:2}"

