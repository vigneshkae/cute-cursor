#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
test_binary="$(mktemp /tmp/cute-cursor-transactions.XXXXXX)"
trap 'rm -f "$test_binary"' EXIT
clang scripts/test-cursor-transactions.c -I Sources/CursorSystem/include -framework ApplicationServices -o "$test_binary"
"$test_binary"
