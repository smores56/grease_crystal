#!/bin/sh

echo '{"query": "{ publicSongs { name url } }"}' | SCRIPT_NAME=/grease/ CONTENT_LENGTH=41 PATH_INFO=/grease/graphiql ./cgi-bin/grease
echo ""
