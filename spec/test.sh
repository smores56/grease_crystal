#!/bin/sh

echo '{"query": "{ publicSongs { title current } }"}' | SCRIPT_NAME=/grease/ CONTENT_LENGTH=46 PATH_INFO=/graphql crystal run --warnings none src/grease.cr
echo ""
