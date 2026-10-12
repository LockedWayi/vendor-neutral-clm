#!/usr/bin/env bash
#
# The Go half of ci/test.sh: vet, then every test under the race detector.
#
# -count=1: the restored build cache carries Go's test result cache, and a
# replayed verdict means the test never ran. It defeats the result cache
# only; compilation stays cached.
#
# A run that executed no test is refused: `go test ./...` over packages
# with no tests exits 0.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=ci/pins.sh
. "$REPO_ROOT/ci/pins.sh"

LOG="$REPO_ROOT/.local/test/go-test.log"
mkdir -p "$(dirname "$LOG")"

echo "==> go vet ./..."
inToolchain go vet ./...

echo "==> go test -race -count=1 ./..."
status=0
inToolchain go test -race -count=1 -v ./... >"$LOG" 2>&1 || status=$?
grep -vE '^(=== (RUN|PAUSE|CONT)|\s+--- PASS)' "$LOG" || true

passed="$(grep -cE '^\s*--- PASS' "$LOG" || true)"
skipped="$(grep -cE '^\s*--- SKIP' "$LOG" || true)"
failed="$(grep -cE '^\s*--- FAIL' "$LOG" || true)"
echo "    tests: ${passed} passed, ${skipped} skipped, ${failed} failed (every depth; full log: .local/test/go-test.log)"

[ "$status" -eq 0 ] || exit "$status"
if [ "$passed" -eq 0 ]; then
    echo "test: no test passed; refusing to report a clean run over nothing" >&2
    exit 1
fi
