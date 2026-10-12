#!/usr/bin/env bash
#
# The suite gate: build the code and run every test, in the pinned
# toolchain.
#
#   ci/test.sh
#
# The language half lives in ci/lang/test.sh. It refuses a run that
# executed no test, because "0 tests, 0 failures" and "the suite never
# started" both exit 0.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$REPO_ROOT/ci/lang/test.sh" "$@"
