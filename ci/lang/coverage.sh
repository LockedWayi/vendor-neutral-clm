#!/usr/bin/env bash
#
# The Go half of ci/coverage.sh: measure, and write one number.
#
#   ci/lang/coverage.sh <exclude-file> <percent-out>     (repository-relative)
#
# The policy (the floor) is ci/coverage.sh's. Every package is counted,
# including ones with no tests, which Go reports at 0%.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=ci/pins.sh
. "$REPO_ROOT/ci/pins.sh"
cd "$REPO_ROOT"

EXCLUDE="$1"
PCT_OUT="$2"
RAW=.local/coverage/go-raw.out
FILTERED=.local/coverage/go-filtered.out
mkdir -p .local/coverage

# atomic: -race requires it. -count=1: see ci/lang/test.sh.
inToolchain go test -race -count=1 -covermode=atomic -coverprofile="$RAW" ./... >/dev/null

# The profile's first line is the mode header; each later line starts
# with the file's import path, so a repository-relative path matches as a
# substring.
head -n1 "$RAW" >"$FILTERED"
patterns="$(grep -vE '^[[:space:]]*(#|$)' "$EXCLUDE" || true)"
if [ -n "$patterns" ]; then
    tail -n +2 "$RAW" | grep -v -F -f <(printf '%s\n' "$patterns") >>"$FILTERED" || true
else
    tail -n +2 "$RAW" >>"$FILTERED"
fi
[ "$(wc -l <"$FILTERED")" -gt 1 ] || { echo "coverage: the profile holds no statements" >&2; exit 1; }

summary="$(inToolchain go tool cover -func="$FILTERED")"
echo "$summary"
echo "$summary" | tail -1 | grep -oE '[0-9]+\.[0-9]+' >"$PCT_OUT"
