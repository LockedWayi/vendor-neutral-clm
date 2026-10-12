#!/usr/bin/env bash
#
# Run shellcheck over every shell script this repository tracks.
#
#   ci/lint-shell.sh
#
# Every gate is a shell script, so the gates are code too, and a gate with
# a quoting bug can exit 0 over a scan that never happened.
#
# Warning and above fail; info and style are reported nowhere, so a finding
# here is one worth a change. -x follows the files a script sources; a
# sourced file carries a `shell=bash` directive because it has no shebang
# by design. Exceptions are `disable` directives on the line they cover,
# each with its reason beside it.
#
# Scripts inside workflow `run:` blocks are YAML strings and are not
# covered. Keep each one to one call of a script under ci/.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=ci/pins.sh
. "$REPO_ROOT/ci/pins.sh"
cd "$REPO_ROOT"

# Only files this repository tracks, so a dependency's scripts inside a
# restored cache are not linted.
mapfile -d '' SCRIPTS < <(git ls-files -z -- '*.sh')
[ "${#SCRIPTS[@]}" -gt 0 ] || { echo "lint-shell: git ls-files found no *.sh; refusing to report a clean run over nothing" >&2; exit 1; }

echo "==> shellcheck -x -S warning over ${#SCRIPTS[@]} tracked scripts"
docker run --rm -v "$REPO_ROOT":/repo:ro -w /repo "$SHELLCHECK_IMAGE" \
    -x -S warning -- "${SCRIPTS[@]}"
echo "    clean"
