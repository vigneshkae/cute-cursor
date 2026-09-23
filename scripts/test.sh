#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
# Keep signed XCTest bundles outside cloud-synced folders.
swift test --scratch-path "${TMPDIR:-/tmp}/cursor-studio-test-build"

./scripts/test-transactions.sh
