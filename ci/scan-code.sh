#!/usr/bin/env bash
#
# SAST: Semgrep over this repository's own code.
#
#   ci/scan-code.sh
#
# The secret scan reads what was committed, the dependency scan reads what
# was imported, and this reads what was written here.
#
# Rulesets: p/security-audit plus the language's own (SEMGREP_LANG_RULESETS
# in ci/lang/pins.sh). Not p/secrets: gitleaks owns that question over the
# full history. --error makes this a gate.
#
# Exceptions are per-rule, per-line `nosemgrep: <rule-id>` comments in the
# source, each with its reason. Never a disabled ruleset and never a path
# exclusion, which would exempt every future finding in that file too.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=ci/pins.sh
. "$REPO_ROOT/ci/pins.sh"

configs=(--config=p/security-audit)
for rs in "${SEMGREP_LANG_RULESETS[@]}"; do
    configs+=("--config=$rs")
done

# --metrics=off: no telemetry. --exclude=.local: gitignored working state.
# The JSON report is what proves files were scanned; exit status alone
# cannot tell a clean scan from one that read nothing.
mkdir -p "$REPO_ROOT/.local/scan"
docker run --rm -v "$REPO_ROOT":/src -w /src --user "$(id -u):$(id -g)" \
    -e HOME=/tmp -e SEMGREP_SEND_METRICS=off \
    "$SEMGREP_IMAGE" \
    semgrep scan "${configs[@]}" --metrics=off --error --exclude=.local \
    --json-output=/src/.local/scan/semgrep.json

scanned="$(toolsPython -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["paths"]["scanned"]))' /repo/.local/scan/semgrep.json)"
if [ "$scanned" -eq 0 ]; then
    echo "scan-code: Semgrep scanned 0 files; refusing to report a clean run over nothing" >&2
    exit 1
fi
echo
echo "==> clean: no Semgrep findings in ${scanned} files"
