#!/usr/bin/env bash
#
# Formatting, vet or type checking, and lint over this repository's own
# code, in the pinned toolchain.
#
#   ci/lint-code.sh
#
# The language half lives in ci/lang/lint.sh. Exceptions are directives on
# the line they cover, each with its reason beside it. Never a disabled
# linter and never an excluded path.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$REPO_ROOT/ci/lang/lint.sh" "$@"
