#!/usr/bin/env bash
#
# Dependency vulnerability scanning: two questions, asked separately.
#
#   trivy fs         is a vulnerable version present at all? Reads the
#                    manifests and lockfiles, blocks on HIGH or CRITICAL.
#   the language     govulncheck (Go): does this code reach the vulnerable
#   scanner          function? pip-audit (Python): is a vulnerable version
#                    installed in the environment the tests run in?
#                    Chosen in ci/lang/pins.sh, run by ci/lang/scan-deps.sh.
#
# Exceptions to either come from one reviewed file, ci/vuln-allowlist.yaml.
# trivy reads it natively; ci/vuln-gate.py applies it to the language
# scanner. Each scanner records which entries it used, and the last step
# fails on an entry that suppressed nothing in any of them.
#
#   ci/scan-deps.sh
#
# Needs docker and network: vulnerability databases are fetched at scan
# time.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=ci/pins.sh
. "$REPO_ROOT/ci/pins.sh"

OUT="$REPO_ROOT/.local/scan"
mkdir -p "$OUT/trivy-cache"
rm -f "$OUT"/hits-*.json "$OUT/lang-report.json"
allowlistJSON >"$OUT/allowlist.json"

echo "==> ${LANG_DEPS_SCANNER}"
"$REPO_ROOT/ci/lang/scan-deps.sh" .local/scan/lang-report.json
[ -s "$OUT/lang-report.json" ] || { echo "scan-deps: ${LANG_DEPS_SCANNER} wrote no report; treat this as a failed scan, not a clean one" >&2; exit 1; }
toolsPython /repo/ci/vuln-gate.py filter /repo/.local/scan/allowlist.json \
    "$LANG_DEPS_SCANNER" /repo/.local/scan/lang-report.json \
    "/repo/.local/scan/hits-${LANG_DEPS_SCANNER}.json" "$LANG_DEPS_SCANNER"

echo
echo "==> trivy fs: HIGH and CRITICAL in the dependency graph"
# .local/ holds trivy's own database; scanning it means scanning the
# scanner.
TRIVY_FS_ARGS=(
    fs --scanners vuln --severity "HIGH,CRITICAL"
    --ignorefile /repo/ci/vuln-allowlist.yaml --skip-dirs .local
    "${TRIVY_FS_LANG_ARGS[@]}"
    --quiet --skip-version-check --no-progress /repo
)
trivy() {
    docker run --rm -v "$REPO_ROOT":/repo:ro -v "$OUT":/out -w /repo \
        --user "$(id -u):$(id -g)" -e HOME=/tmp \
        "$TRIVY_IMAGE" --cache-dir /out/trivy-cache "$@"
}
trivy "${TRIVY_FS_ARGS[@]}" --exit-code 1

# A second pass only collects: which entries did trivy use? The gate
# verdict above keeps its own exit status and table. --show-suppressed is
# what makes a used entry visible; without it every entry reads as unused.
trivy "${TRIVY_FS_ARGS[@]}" --show-suppressed --format json --output /out/trivy-fs.json
toolsPython /repo/ci/vuln-gate.py trivy-hits /repo/.local/scan/allowlist.json \
    /repo/.local/scan/trivy-fs.json /repo/.local/scan/hits-trivy-fs.json trivy-fs
lockfiles="$(toolsPython -c 'import json,sys; r=json.load(open(sys.argv[1])); print(sum(1 for x in r.get("Results") or [] if x.get("Class")=="lang-pkgs"))' /repo/.local/scan/trivy-fs.json)"
# A manifest trivy does not recognise by name is a manifest it did not
# read, and the scan above then reports clean over nothing. That happened
# with requirements-dev.txt before TRIVY_FS_LANG_ARGS named it.
if [ "$lockfiles" -eq 0 ]; then
    echo "scan-deps: trivy fs read 0 dependency manifests; name them in TRIVY_FS_LANG_ARGS (ci/lang/pins.sh)" >&2
    exit 1
fi
echo "    trivy fs read ${lockfiles} dependency manifest(s)"

echo
echo "==> allowlist entries against what the scanners actually suppressed"
toolsPython /repo/ci/vuln-gate.py require-used /repo/.local/scan/allowlist.json \
    "trivy-fs,${LANG_DEPS_SCANNER}" \
    /repo/.local/scan/hits-trivy-fs.json "/repo/.local/scan/hits-${LANG_DEPS_SCANNER}.json"

echo
echo "==> clean: no blocking dependency vulnerabilities"
