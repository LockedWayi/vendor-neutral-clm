#!/usr/bin/env bash
#
# Every third-party image is pinned by digest and every workflow action by
# commit SHA.
#
#   ci/check-pins.sh
#
# A tag is a pointer its publisher can move, so a tag-pinned image is an
# image whose contents are chosen by someone else after your review. The
# rule is only true while something checks it; this is that check.
#
# What counts as a reference:
#   - a FROM line in any tracked Dockerfile (an earlier stage of the same
#     file is not third-party and needs no digest);
#   - an *_IMAGE= assignment in any tracked script (ci/pins.sh is where
#     they belong);
#   - a `docker run` in a tracked script that names an image literally
#     instead of through an *_IMAGE variable;
#   - `uses:`, `image:` and `container:` in workflows.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

failures=0
checked=0
fail() { printf '  UNPINNED  %s\n' "$*" >&2; failures=$((failures + 1)); }
ok() { checked=$((checked + 1)); }

# Only files this repository tracks. Walking the working tree would read a
# dependency's Dockerfile inside a restored module cache.
tracked() { git ls-files -z -- "$@"; }

echo "==> Dockerfile FROM lines"
while IFS= read -r -d '' file; do
    while IFS= read -r line; do
        ref="$(printf '%s' "$line" | sed -E 's/^FROM +(--[^ ]+ +)*([^ ]+).*/\2/I')"
        if [[ "$ref" == *@sha256:* ]]; then ok
        elif grep -qiE "^FROM .* AS +${ref}\$" "$file"; then ok
        else fail "$file: $line"; fi
    done < <(grep -iE '^FROM ' "$file" || true)
done < <(tracked '*Dockerfile*')

echo "==> image variables and docker run lines in scripts"
while IFS= read -r -d '' file; do
    while IFS= read -r hit; do
        case "$hit" in
            *@sha256:[0-9a-f]*) ok ;;
            *) fail "$file: $hit" ;;
        esac
    done < <(grep -nE '^[[:space:]]*[A-Z_]*_IMAGE=' "$file" | grep -vE '_IMAGE="?\$' || true)
    # A docker run whose image is a literal rather than "$…_IMAGE". The
    # check is on the whole logical command, joined across backslashes.
    while IFS= read -r cmd; do
        case "$cmd" in
            *'_IMAGE'*|*'IMAGE}'*) ok ;;
            *) fail "$file: docker run without a pinned *_IMAGE variable: ${cmd:0:120}" ;;
        esac
    done < <(sed -e ':a' -e '/\\$/N; s/\\\n//; ta' "$file" | grep -E '(^|[;&|(])[[:space:]]*docker run ' || true)
done < <(tracked '*.sh')

echo "==> workflow uses:, image: and container:"
while IFS= read -r -d '' file; do
    while IFS= read -r hit; do
        ref="$(printf '%s' "$hit" | sed -E 's/^[^:]*:[[:space:]-]*(uses|image|container):[[:space:]]*//; s/[[:space:]]+#.*$//; s/["'\'']//g')"
        if [[ "$ref" == ./* ]]; then ok                     # a local action in this repository
        elif [[ "$ref" == *@sha256:* ]]; then ok
        elif [[ "$ref" =~ @[0-9a-f]{40}$ ]]; then ok
        else fail "$file: $hit"; fi
    done < <(grep -nE '^[[:space:]-]*(uses|image|container):[[:space:]]*[^[:space:]{]' "$file" || true)
done < <(tracked '.github/workflows/*.yml' '.github/workflows/*.yaml')

echo
if [ "$failures" -ne 0 ]; then
    echo "check-pins: $failures unpinned reference(s). Pin images by digest in ci/pins.sh and actions by commit SHA." >&2
    exit 1
fi
[ "$checked" -gt 0 ] || { echo "check-pins: examined 0 references; refusing to report a clean run over nothing" >&2; exit 1; }
echo "check-pins: ${checked} reference(s), every one pinned"
