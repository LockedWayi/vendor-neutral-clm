#!/usr/bin/env bash
#
# The Go half of ci/lint-code.sh: gofmt, go vet, golangci-lint (.golangci.yml).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=ci/pins.sh
. "$REPO_ROOT/ci/pins.sh"
cd "$REPO_ROOT"

# Tracked files only: gofmt over `.` would walk the module cache in .local/.
mapfile -d '' GOFILES < <(git ls-files -z -- '*.go')
[ "${#GOFILES[@]}" -gt 0 ] || { echo "lint: no tracked *.go files; refusing to report a clean run over nothing" >&2; exit 1; }

echo "==> gofmt -l over ${#GOFILES[@]} tracked files"
unformatted="$(inToolchain gofmt -l "${GOFILES[@]}")"
if [ -n "$unformatted" ]; then
    echo "gofmt wants to reformat:" >&2
    echo "$unformatted" >&2
    exit 1
fi

echo "==> go vet ./..."
inToolchain go vet ./...

echo "==> golangci-lint ${GOLANGCI_LINT_VERSION}"
lint="$(goTool github.com/golangci/golangci-lint/v2/cmd/golangci-lint "$GOLANGCI_LINT_VERSION")"
inToolchain "$lint" run ./...
echo "    clean"
