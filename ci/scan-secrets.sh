#!/usr/bin/env bash
#
# Scan every commit for secrets with gitleaks, as the pipeline does.
#
#   ci/scan-secrets.sh
#
# The subject is the history, not the working tree: a secret committed
# and deleted in the next commit is still published. A shallow clone would
# scan only the tip, so one is refused.
#
# Exceptions: a recurring public string gets an exact-match regex in
# .gitleaks.toml; a one-off historical finding gets a commit-pinned
# fingerprint in .gitleaksignore. Each with its reason. Never a path.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=ci/pins.sh
. "$REPO_ROOT/ci/pins.sh"

if [ "$(git -C "$REPO_ROOT" rev-parse --is-shallow-repository)" = "true" ]; then
    echo "scan-secrets: this is a shallow clone, so the scan would cover only the tip." >&2
    echo "Fetch the full history first: git fetch --unshallow" >&2
    exit 1
fi
commits="$(git -C "$REPO_ROOT" rev-list --all --count)"
[ "$commits" -gt 0 ] || { echo "scan-secrets: no commits to scan" >&2; exit 1; }

# The GIT_CONFIG_* variables tell git inside the container that the
# checkout, owned by another uid, is safe to read.
docker run --rm -v "$REPO_ROOT":/repo:ro -w /repo \
    -e GIT_CONFIG_COUNT=1 \
    -e GIT_CONFIG_KEY_0=safe.directory \
    -e GIT_CONFIG_VALUE_0='*' \
    "$GITLEAKS_IMAGE" \
    git . --config .gitleaks.toml --redact --no-banner

echo
echo "==> clean: no secrets in any of ${commits} commits"
