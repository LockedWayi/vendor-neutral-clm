#!/usr/bin/env bash
#
# The Go half of ci/scan-deps.sh: govulncheck, which builds the call graph
# and says whether this code reaches a vulnerable function, in the
# standard library as well as in modules.
#
#   ci/lang/scan-deps.sh <report-out>      (repository-relative)
#
# -format json always exits 0; the verdict is ci/vuln-gate.py's, after
# the allowlist is applied. It refuses a report with no config message,
# which is what a scan that never started looks like.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=ci/pins.sh
. "$REPO_ROOT/ci/pins.sh"

REPORT="$1"
govulncheck="$(goTool golang.org/x/vuln/cmd/govulncheck "$GOVULNCHECK_VERSION")"
inToolchain "$govulncheck" -format json ./... >"$REPO_ROOT/$REPORT"
echo "    govulncheck ${GOVULNCHECK_VERSION} wrote $(wc -c <"$REPO_ROOT/$REPORT") bytes"
