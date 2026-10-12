# shellcheck shell=bash
# Sourced by ci/pins.sh: every name defined here is read by a script that
# sources that file.
# shellcheck disable=SC2034
# The Go half of the pins. Images by digest; Go tools by module version,
# which the module proxy's checksum database makes immutable.

# golang:1.27-bookworm (go1.27.1). The toolchain every Go step runs in:
# build, vet, tests, coverage, lint and govulncheck, so the standard-library
# half of the vulnerability answer is about the toolchain that builds.
# GOTOOLCHAIN=local below stops go.mod from swapping it for another.
GO_IMAGE="golang@sha256:69a7b9788769bec032d238959b61854e9ae87f57be9029ec04e9885fabf99195"

# golang.org/x/vuln/cmd/govulncheck
GOVULNCHECK_VERSION="v1.8.0"

# github.com/golangci/golangci-lint/v2/cmd/golangci-lint
GOLANGCI_LINT_VERSION="v2.14.0"

# Read by ci/scan-code.sh and ci/scan-deps.sh.
SEMGREP_LANG_RULESETS=(p/golang)
LANG_DEPS_SCANNER="govulncheck"
# trivy finds go.mod and go.sum by name; nothing to add.
TRIVY_FS_LANG_ARGS=()

# inToolchain runs a command in GO_IMAGE with the repository at /repo, as
# the calling user so nothing it writes is root-owned. Module, build and
# tool caches live under .local/ci-cache, which the workflow restores.
# Result caches are defeated by -count=1 at each call site instead: a
# replayed test result is not a run.
inToolchain() {
    local repo_root
    repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    mkdir -p "$repo_root/.local/ci-cache/gomod" "$repo_root/.local/ci-cache/gobuild" "$repo_root/.local/ci-cache/gopath"
    docker run --rm -v "$repo_root":/repo -w /repo --user "$(id -u):$(id -g)" \
        -e HOME=/tmp -e GOTOOLCHAIN=local \
        -e GOPATH=/repo/.local/ci-cache/gopath \
        -e GOMODCACHE=/repo/.local/ci-cache/gomod \
        -e GOCACHE=/repo/.local/ci-cache/gobuild \
        -e GOLANGCI_LINT_CACHE=/repo/.local/ci-cache/golangci \
        "$GO_IMAGE" "$@"
}

# goTool installs a pinned Go tool into the cached GOPATH once, and prints
# the path it runs from inside the container.
goTool() {
    local module="$1" version="$2" bin
    bin="$(basename "$module")"
    local log
    log="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/.local/ci-cache/go-install-$bin.log"
    mkdir -p "$(dirname "$log")"
    # The install's download chatter goes to a log, shown only on failure.
    if ! inToolchain sh -c "test -x \"\$GOPATH/bin/$bin.$version\" || { go install $module@$version && mv \"\$GOPATH/bin/$bin\" \"\$GOPATH/bin/$bin.$version\"; }" >"$log" 2>&1; then
        cat "$log" >&2
        echo "goTool: installing $module@$version failed" >&2
        return 1
    fi
    printf '/repo/.local/ci-cache/gopath/bin/%s.%s' "$bin" "$version"
}
