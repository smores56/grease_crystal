#!/bin/bash

UPLOAD_URL = "https://gleeclub.gatech.edu/cgi-bin/admin_tools/upload_api"

crystal build hello_world.cr --release --no-debug --static src/grease.cr \
  && curl "$UPLOAD_URL" -H "token: $GREASE_TOKEN" --data-binary "@grease"
