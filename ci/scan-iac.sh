#!/usr/bin/env bash
#
# Misconfiguration scan over what would be provisioned or built:
# Dockerfiles, Kubernetes manifests, Helm charts and IaC, with trivy
# config, blocking on HIGH or CRITICAL; and trivy's secret scanner over
# deploy/, which pattern-matches file contents whatever the format.
#
#   ci/scan-iac.sh
#
# A clean run is a narrow claim: trivy has rules for the formats it knows,
# and a provider it has no rules for produces no findings rather than an
# error. The count of candidate files is printed so a reader can tell
# "nothing wrong" from "nothing here yet". A new project has nothing here
# yet, and says so.
#
# When deploy/ gains IaC with its own formatter and validator (tofu fmt,
# tofu validate, helm lint), add them here: a file trivy cannot parse
# produces no findings rather than an error.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=ci/pins.sh
. "$REPO_ROOT/ci/pins.sh"
cd "$REPO_ROOT"

OUT="$REPO_ROOT/.local/scan"
mkdir -p "$OUT/trivy-cache"
trivy() {
    docker run --rm -v "$REPO_ROOT":/repo:ro -v "$OUT":/out -w /repo \
        --user "$(id -u):$(id -g)" -e HOME=/tmp \
        "$TRIVY_IMAGE" --cache-dir /out/trivy-cache "$@"
}

candidates="$(git ls-files -- '*Dockerfile*' '*.tf' '*.tofu' '*.hcl' 'deploy/*.yaml' 'deploy/*.yml' '*Chart.yaml' | wc -l | tr -d ' ')"
echo "==> trivy config: HIGH and CRITICAL misconfigurations (${candidates} candidate file(s) tracked)"
trivy config --exit-code 1 --severity HIGH,CRITICAL --skip-dirs .local \
    --quiet --skip-version-check /repo

echo
echo "==> trivy: secrets under deploy/"
[ -d "$REPO_ROOT/deploy" ] || { echo "scan-iac: deploy/ is missing; the layout in BLUEPRINT.md section 2 expects it" >&2; exit 1; }
trivy fs --scanners secret --exit-code 1 \
    --quiet --skip-version-check --no-progress /repo/deploy

echo
if [ "$candidates" -eq 0 ]; then
    echo "==> clean: no infrastructure files tracked yet; trivy had nothing to read"
else
    echo "==> clean: ${candidates} infrastructure file(s), no blocking findings"
fi
