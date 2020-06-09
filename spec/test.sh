#!/bin/sh

echo '{"query": "{ publicSongs { name url } }"}' | SCRIPT_NAME=/grease/ CONTENT_LENGTH=41 PATH_INFO=/graphql crystal run --warnings none src/grease.cr
echo ""
