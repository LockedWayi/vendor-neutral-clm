# shellcheck shell=bash
# Sourced: every name defined here is read by the script that sources it.
# shellcheck disable=SC2034
# Pinned third-party references, in one place. Sourced, never executed:
#
#   . "$(dirname "${BASH_SOURCE[0]}")/pins.sh"
#
# Images are pinned by digest. A tag is a pointer its publisher can move.
# The tag beside each digest is for the reader; Docker resolves the digest.
# ci/check-pins.sh fails on an *_IMAGE assignment without one.
#
# Language-specific pins (the toolchain image, the linters, the dependency
# scanner) live in ci/lang/pins.sh, sourced at the end of this file.

# aquasec/trivy:0.74.0
TRIVY_IMAGE="aquasec/trivy@sha256:62b1e65e8869bc4b4c6aa4fa2b21595256c7c2f6018a9d9ad61caf87187c1969"

# semgrep/semgrep:1.178.0
SEMGREP_IMAGE="semgrep/semgrep@sha256:32e459968daabe7ab86968184a29109b9564aa00392401156f9788452b42786b"

# zricethezav/gitleaks:v8.30.1
GITLEAKS_IMAGE="zricethezav/gitleaks@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f"

# koalaman/shellcheck:v0.11.0
SHELLCHECK_IMAGE="koalaman/shellcheck@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d"

# mikefarah/yq:4 (v4.54.1). Turns ci/vuln-allowlist.yaml into JSON so the
# checks below can read it with the standard library alone.
YQ_IMAGE="mikefarah/yq@sha256:4b3d9475d65571d28cbb19544d3820ec2945e4c8b2f18279394282b8dc3a592e"

# python:3.14-slim (3.14.7). Runs the repository's own small checkers
# (ci/vuln-gate.py, the link checker), standard library only, so the host's
# Python version never decides a verdict.
TOOLS_PYTHON_IMAGE="python@sha256:51dafde81dbdb6ebde285137a295cf18a47ca95234fe388a343719cb97305b3d"

# toolsPython runs `python3 <args>` in TOOLS_PYTHON_IMAGE with the
# repository mounted at /repo, read-only except for .local/. Paths in the
# arguments are written as the container sees them: /repo/... .
toolsPython() {
    local repo_root
    repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    mkdir -p "$repo_root/.local"
    docker run --rm -i \
        -v "$repo_root":/repo:ro -v "$repo_root/.local":/repo/.local \
        -w /repo --user "$(id -u):$(id -g)" \
        "$TOOLS_PYTHON_IMAGE" python3 "$@"
}

# allowlistJSON prints ci/vuln-allowlist.yaml as JSON.
allowlistJSON() {
    local repo_root
    repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    docker run --rm -v "$repo_root":/repo:ro -w /repo \
        "$YQ_IMAGE" -o=json '.' ci/vuln-allowlist.yaml
}

# shellcheck source=ci/lang/pins.sh
. "$(dirname "${BASH_SOURCE[0]}")/lang/pins.sh"
