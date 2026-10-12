#!/usr/bin/env bash
#
# Compute test coverage over the code CI can run, and fail below the floor.
#
#   ci/coverage.sh
#   COVERAGE_THRESHOLD=80 ci/coverage.sh
#
# ci/lang/coverage.sh measures and writes one number; this script owns the
# policy. The floor lives here and nowhere else, so lowering it is a
# visible change to one line.
#
# ci/coverage-exclude.txt lists code CI has no way to run (an adapter for
# something CI does not have), never code that is merely hard to test. Each
# entry there says what verifies that code instead.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THRESHOLD="${COVERAGE_THRESHOLD:-70}"
OUT_DIR="$REPO_ROOT/.local/coverage"
PCT_FILE="$OUT_DIR/percent"
mkdir -p "$OUT_DIR"
rm -f "$PCT_FILE"

"$REPO_ROOT/ci/lang/coverage.sh" ci/coverage-exclude.txt .local/coverage/percent

# A measurement that produced no number is a failed measurement, not 0%
# and not a pass.
[ -s "$PCT_FILE" ] || { echo "coverage: ci/lang/coverage.sh wrote no figure to $PCT_FILE" >&2; exit 1; }
PCT="$(tr -d '[:space:]' <"$PCT_FILE")"
case "$PCT" in
    ''|*[!0-9.]*) echo "coverage: '$PCT' is not a percentage" >&2; exit 1 ;;
esac

if ! awk -v pct="$PCT" -v threshold="$THRESHOLD" 'BEGIN { exit !(pct >= threshold) }'; then
    echo "coverage ${PCT}% is below the ${THRESHOLD}% floor (exclusions: ci/coverage-exclude.txt)" >&2
    exit 1
fi
echo "coverage ${PCT}% meets the ${THRESHOLD}% floor (exclusions: ci/coverage-exclude.txt)"
