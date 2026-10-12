#!/usr/bin/env bash
#
# Refuse an allowlist entry without an id, a reason or an expiry, or one
# that has expired or runs more than 180 days out.
#
#   ci/check-allowlist.sh
#
# trivy reads ci/vuln-allowlist.yaml natively and will honour an entry
# with no expiry forever without complaint. This is the check trivy does
# not make. Whether each entry still suppresses something is a different
# question, answered at the end of ci/scan-deps.sh.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=ci/pins.sh
. "$REPO_ROOT/ci/pins.sh"

mkdir -p "$REPO_ROOT/.local/scan"
allowlistJSON >"$REPO_ROOT/.local/scan/allowlist.json"
toolsPython /repo/ci/vuln-gate.py validate /repo/.local/scan/allowlist.json
