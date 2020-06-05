#!/bin/sh

echo '{"query": "{ publicSongs { name url } }"}' | SCRIPT_NAME=/grease/ CONTENT_LENGTH=41 PATH_INFO=/grease/graphiql crystal src/grease.cr
echo ""
