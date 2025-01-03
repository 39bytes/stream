#!/usr/bin/sh

rm -f src/env.gleam

set -a && source ./.env || true && set +a

echo "pub const api_url = \"$API_URL\"" >>src/env.gleam
echo "pub const mode = \"$MODE\"" >>src/env.gleam
echo "pub const server_url = \"$SERVER_URL\"" >>src/env.gleam
echo "pub const local_url = \"$LOCAL_URL\"" >>src/env.gleam
