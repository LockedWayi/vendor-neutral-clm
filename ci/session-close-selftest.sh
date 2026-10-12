#!/usr/bin/env bash
#
# Prove that tools/session-close.sh refuses each of its reasons and
# accepts a clean close.
#
#   ci/session-close-selftest.sh
#
# A guard nobody has seen refuse is decoration (docs/BLUEPRINT.md §7).
# This builds a throwaway repository that satisfies every check, shows
# the gate exit 0, then breaks one thing at a time and shows the gate exit
# 1 with that check, and only that check, red in .local/state.json. It
# also drives the --hook mode: a turn with no tool use is never blocked, a
# red close blocks (exit 2) with the reasons on stderr, and the fourth
# block in one session lets the stop through.
#
# `gh` is replaced by a stub on PATH that answers `gh run list` from a
# file, because the question here is what the gate does with an answer,
# not whether GitHub gives one. `git` is real: a bare repository stands in
# for origin. Nothing outside a temporary directory is touched, and no
# container is needed, so this runs on any host with bash and git.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export HOME="$work/home"          # git identity and gh config stay inside the sandbox
mkdir -p "$HOME"
export GIT_CONFIG_GLOBAL="$HOME/.gitconfig"
git config --global user.name selftest
git config --global user.email selftest@example.invalid
git config --global init.defaultBranch main

today="$(date +%F)"
yesterday="$(date -d yesterday +%F 2>/dev/null || date -v-1d +%F)"
passed=0; failed=0
pass() { printf '  ok    %s\n' "$1"; passed=$((passed + 1)); }
fail() { printf '  FAIL  %s\n' "$1" >&2; failed=$((failed + 1)); }

# --- the stub gh ---------------------------------------------------------------
# It prints the contents of $FAKE_GH_RUNS for `gh run list` (one
# "status conclusion name" line per run) and refuses anything else.
mkdir -p "$work/bin"
cat >"$work/bin/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
    "run list") cat "${FAKE_GH_RUNS:?}" ;;
    *) echo "stub gh: unexpected call: $*" >&2; exit 97 ;;
esac
STUB
chmod +x "$work/bin/gh"
export PATH="$work/bin:$PATH"
export FAKE_GH_RUNS="$work/runs.txt"
printf 'completed success ci\n' >"$FAKE_GH_RUNS"

# --- a repository that passes every check -------------------------------------
# Named like a project, because check-progress compares the two; the
# close gate itself does not.
repo="$work/closeme"
mkdir -p "$repo/tools" "$repo/docs/phases"
cp "$REPO_ROOT/tools/frontmatter.sh" "$REPO_ROOT/tools/session-close.sh" "$repo/tools/"
mkdir -p "$repo/tools/session-close.d"
cp "$REPO_ROOT/tools/session-close.d/README.md" "$repo/tools/session-close.d/"
printf '.local/\n' >"$repo/.gitignore"
write_progress() {  # write_progress <updated> <needs_owner> <needs_owner_why>
    cat >"$repo/docs/PROGRESS.md" <<PROGRESS
---
project: closeme
status: active
phase: "01"
phase_status: in progress
next: >-
  Do the next thing.
blocked_on: ""
needs_owner: $2
needs_owner_why: "$3"
updated: $1
---

# Progress

## Open decisions

- none
PROGRESS
}
write_phase() {  # write_phase <frontmatter status> <body status>
    cat >"$repo/docs/phases/01-first.md" <<PHASE
---
id: "01"
name: first
status: $1
done_on: ""
depends_on: []
---

# Phase 01: first

**Status on $today:** $2
PHASE
}
write_progress "$today" false ""
write_phase "in progress" "in progress"
printf '# Next session\n\nStart with: do the next thing.\n' >"$repo/docs/next-session.md"
git -C "$repo" init -q
git -C "$repo" add -A
git -C "$repo" commit -q -m "chore: a repository that closes"
# A second commit, so HEAD~1 exists and the next-session freshness check
# has a parent to compare with.
printf 'x\n' >"$repo/README.md"
git -C "$repo" add -A
git -C "$repo" commit -q -m "docs: a readme"
git init -q --bare "$work/origin.git"
git -C "$repo" remote add origin "$work/origin.git"
git -C "$repo" push -q -u origin main
touch "$repo/docs/next-session.md"

close() { (cd "$repo" && tools/session-close.sh "$@"); }
# land: commit and push whatever a mutation changed, so the only red is
# the one the mutation meant.
land() { git -C "$repo" add -A && git -C "$repo" commit -q -m "test: $1" && git -C "$repo" push -q origin main; [ -f "$repo/docs/next-session.md" ] && touch "$repo/docs/next-session.md"; true; }
red_gates() { grep -oE '"id": "[^"]+", "ok": false' "$repo/.local/state.json" | sed -E 's/"id": "([^"]+)".*/\1/' | tr '\n' ' ' | sed 's/ $//'; }
expect_red() {  # expect_red <label> <gate id> : the last close must have exited 1 with exactly that gate red
    local label="$1" want="$2" rc="$3"
    local got; got="$(red_gates)"
    if [ "$rc" = 1 ] && [ "$got" = "$want" ]; then pass "$label → exit 1, red: $want"
    else fail "$label → exit $rc, red: '${got:-none}' (wanted exit 1, red: $want)"; fi
}
base="$(git -C "$repo" rev-parse HEAD)"
# reset_clean: back to the baseline commit, in the tree and in origin, so
# every mutation starts from the same green state.
reset_clean() {
    git -C "$repo" reset -q --hard "$base"
    git -C "$repo" clean -qfd -e .local
    git -C "$repo" push -qf origin main
    printf 'completed success ci\n' >"$FAKE_GH_RUNS"
    touch "$repo/docs/next-session.md"
}

echo "==> the clean close"
rc=0; out="$(close 2>&1)" || rc=$?; if [ "$rc" = 0 ]; then pass "everything satisfied → exit 0"; else fail "everything satisfied → exit $rc (wanted 0)"; printf "%s\n" "$out" >&2; fi
[ -f "$repo/.local/state.json" ] && grep -q '^  "ok": true' "$repo/.local/state.json" && pass "state.json says ok: true" || fail "state.json missing or not ok"

echo "==> each refusal, one at a time"
reset_clean; write_progress "$yesterday" false ""; land "stale"
rc=0; close >/dev/null || rc=$?; expect_red "0 PROGRESS updated yesterday" "progress-frontmatter" "$rc"

reset_clean; printf 'y\n' >"$repo/README.md"; git -C "$repo" commit -qam "docs: unpushed"
rc=0; close >/dev/null || rc=$?; expect_red "1a an unpushed commit" "pushed" "$rc"

reset_clean; printf 'dirty\n' >"$repo/scratch"
rc=0; out="$(close 2>&1)" || rc=$?; expect_red "1b a dirty tree" "clean-tree" "$rc"
printf '%s' "$out" | grep -q 'scratch' && pass "1b the dirty path is named" || fail "1b the dirty path is not named"

reset_clean; : >"$FAKE_GH_RUNS"
rc=0; close >/dev/null || rc=$?; expect_red "2a no CI run for HEAD" "ci-green" "$rc"

reset_clean; printf 'completed success ci\ncompleted failure sast\n' >"$FAKE_GH_RUNS"
rc=0; close >/dev/null || rc=$?; expect_red "2b one red run among green ones" "ci-green" "$rc"

reset_clean; printf 'in_progress  ci\n' >"$FAKE_GH_RUNS"
rc=0; close >/dev/null || rc=$?; expect_red "2c a run still in progress" "ci-green" "$rc"

reset_clean; write_phase "in progress" "done"; land "disagree"
rc=0; close >/dev/null || rc=$?; expect_red "3 phase frontmatter and body disagree" "phase-status" "$rc"

reset_clean; rm "$repo/docs/next-session.md"; land "no next-session"
rc=0; close >/dev/null || rc=$?; expect_red "4a next-session.md missing" "next-session" "$rc"

reset_clean; touch -d '2000-01-01' "$repo/docs/next-session.md"
rc=0; close >/dev/null || rc=$?; expect_red "4b next-session.md older than HEAD's parent" "next-session" "$rc"

reset_clean; write_progress "$today" true ""; land "needs owner"
rc=0; close >/dev/null || rc=$?; expect_red "5 needs_owner without a reason" "needs-owner" "$rc"

reset_clean; printf '#!/usr/bin/env bash\necho "the position check is red"; exit 1\n' >"$repo/tools/session-close.d/10-fail.sh"; chmod +x "$repo/tools/session-close.d/10-fail.sh"; land "failing hook"
rc=0; out="$(close 2>&1)" || rc=$?; expect_red "6a a repository hook that fails" "hook:10-fail.sh" "$rc"
printf '%s' "$out" | grep -q 'the position check is red' && pass "6a the hook's output is the reason" || fail "6a the hook's output is not shown"

reset_clean; printf '#!/usr/bin/env bash\nexit 0\n' >"$repo/tools/session-close.d/10-noexec.sh"; land "hook without x bit"
rc=0; close >/dev/null || rc=$?; expect_red "6b a hook that is not executable" "hook:10-noexec.sh" "$rc"

reset_clean; printf '#!/usr/bin/env bash\nexit 0\n' >"$repo/tools/session-close.d/10-ok.sh"; chmod +x "$repo/tools/session-close.d/10-ok.sh"; land "passing hook"
if close >/dev/null; then pass "6c a hook that passes keeps the close green"; else fail "6c a passing hook made the close red"; fi

echo "==> the Stop hook"
reset_clean; write_progress "$yesterday" false ""; land "stale again"
rc=0; close --hook <<<'{"session_id":"s1","tool_use_count":0}' >/dev/null 2>&1 || rc=$?
[ "$rc" = 0 ] && pass "red close, turn with no tool use → exit 0 (not blocked)" || fail "no-tool turn → exit $rc (wanted 0)"
rc=0; err="$(close --hook <<<'{"session_id":"s1","tool_use_count":5}' 2>&1 >/dev/null)" || rc=$?
[ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'progress-frontmatter' && pass "red close, turn with work → exit 2 with the reason on stderr" || fail "working turn → exit $rc, stderr: $(printf '%s' "$err" | head -2 | tr '\n' ' ')"
for i in 2 3; do rc=0; close --hook <<<'{"session_id":"s1","tool_use_count":5}' >/dev/null 2>&1 || rc=$?; [ "$rc" = 2 ] || fail "block $i → exit $rc (wanted 2)"; done
rc=0; close --hook <<<'{"session_id":"s1","tool_use_count":5}' >/dev/null 2>&1 || rc=$?
[ "$rc" = 0 ] && pass "fourth block in the same session → exit 0, the stop is allowed" || fail "fourth block → exit $rc (wanted 0)"
rc=0; close --hook <<<'{"session_id":"s2","tool_use_count":5}' >/dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] && pass "a new session is blocked again" || fail "new session → exit $rc (wanted 2)"
reset_clean
rc=0; close --hook <<<'{"session_id":"s3","tool_use_count":5}' >/dev/null 2>&1 || rc=$?
[ "$rc" = 0 ] && pass "green close under the hook → exit 0" || fail "green close under the hook → exit $rc"

echo
if [ "$failed" -ne 0 ]; then echo "session-close-selftest: $failed of $((passed + failed)) checks failed" >&2; exit 1; fi
[ "$passed" -ge 20 ] || { echo "session-close-selftest: only $passed checks ran; refusing to report a clean run over nothing" >&2; exit 1; }
echo "session-close-selftest: $passed checks, every refusal refused and the clean close accepted"
