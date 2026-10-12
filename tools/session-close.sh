#!/usr/bin/env bash
#
# The session-close gate: a session is over only when this exits 0.
#
#   tools/session-close.sh            # run every check, write .local/state.json, exit 1 on any failure
#   tools/session-close.sh --hook     # the same, driven by Claude Code's Stop hook (reads the hook's JSON on stdin)
#
# A session that ends "I think we are done" leaves the next one to find
# out what was not pushed, what CI thought, and which phase file lies.
# This script asks those questions, in this order, and refuses the close
# on the first answer it does not like; every check is still run, so the
# reasons come out together:
#
#   0  docs/PROGRESS.md's frontmatter was written today (`updated`)
#   1  no unpushed commit on the current branch; the tree is clean, or the
#      dirty paths are the refusal
#   2  every CI run for HEAD is complete and green; no run yet is red
#   3  every phase file's frontmatter `status` agrees with its body line
#   4  docs/next-session.md exists and is newer than HEAD's parent
#   5  needs_owner: true comes with a non-empty needs_owner_why
#   6  each tools/session-close.d/*.sh, in order, exits 0
#
# It writes .local/state.json (gitignored): the frontmatter, each gate's
# result, HEAD, the branch and timestamps. The dashboard reads that first
# and falls back to the Markdown when it is absent or stale.
#
# Under --hook, a red close is reported to Claude Code as a block (exit 2,
# reasons on stderr) so the session continues and fixes it, at most three
# times per session: after that the stop is allowed and state.json
# records the red. A turn that used no tool is never blocked; a question
# answered is not a session to close.
#
# Needs bash, git, gh (logged in) and tools/frontmatter.sh. No Python, no
# Go, no YAML parser: the host that runs the gates may have none of them.
# Refuses to run outside a git repository or without gh.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 2
FM="$REPO_ROOT/tools/frontmatter.sh"
PROGRESS="docs/PROGRESS.md"
STATE_DIR=".local"
STATE="$STATE_DIR/state.json"
MAX_HOOK_BLOCKS=3

hook=0
case "${1:-}" in
    --hook) hook=1 ;;
    "") ;;
    -h|--help) sed -n '5,6p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
    *) echo "session-close: unknown argument $1" >&2; exit 2 ;;
esac

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "session-close: not a git repository" >&2; exit 2; }
command -v gh >/dev/null || { echo "session-close: gh is not installed; the CI check cannot run, so the close cannot be green" >&2; exit 2; }
[ -x "$FM" ] || { echo "session-close: $FM is missing or not executable" >&2; exit 2; }

# --- the hook's input --------------------------------------------------------
session_id=""; tool_use_count=""
if [ "$hook" = 1 ]; then
    input="$(cat)"
    session_id="$(printf '%s' "$input" | sed -nE 's/.*"session_id"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' | head -1)"
    tool_use_count="$(printf '%s' "$input" | sed -nE 's/.*"tool_use_count"[[:space:]]*:[[:space:]]*([0-9]+).*/\1/p' | head -1)"
fi

# --- helpers -----------------------------------------------------------------
fails=0
gate_names=(); gate_ok=(); gate_detail=()
gate() {  # gate <id> <ok 0|1> <detail>
    gate_names+=("$1"); gate_ok+=("$2"); gate_detail+=("$3")
    if [ "$2" = 1 ]; then printf '  ok    %s\n' "$1"; else printf '  RED   %s: %s\n' "$1" "$3"; fails=$((fails + 1)); fi
}
json_str() {  # a JSON string literal from $1
    local s="$1"
    s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; s="${s//$'\t'/\\t}"; s="${s//$'\r'/}"
    printf '"%s"' "$s"
}
today="$(date +%F)"
head_sha="$(git rev-parse HEAD 2>/dev/null || echo "")"
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
head_time="$(git log -1 --format=%cI 2>/dev/null || echo "")"

echo "==> session-close on $branch @ ${head_sha:0:12}, $today"

# --- 0  the frontmatter, written today ----------------------------------------
fm_ok=1
declare -A fm
if [ ! -f "$PROGRESS" ]; then
    gate "progress-frontmatter" 0 "$PROGRESS does not exist"; fm_ok=0
else
    for key in project status phase phase_status next blocked_on needs_owner needs_owner_why updated; do
        if v="$("$FM" get "$PROGRESS" "$key" 2>/dev/null)"; then fm["$key"]="$v"; else fm["$key"]=""; fm_ok=0; missing="${missing:-}$key "; fi
    done
    if [ "$fm_ok" = 0 ]; then
        gate "progress-frontmatter" 0 "docs/PROGRESS.md frontmatter lacks or cannot be read: ${missing:-}"
    elif [ "${fm[updated]}" != "$today" ]; then
        gate "progress-frontmatter" 0 "updated is '${fm[updated]}', today is $today; write the frontmatter before closing"
    else
        gate "progress-frontmatter" 1 "updated $today"
    fi
fi

# --- 1  pushed, and clean -----------------------------------------------------
if upstream="$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null)"; then
    ahead="$(git rev-list --count '@{u}..HEAD' 2>/dev/null || echo "?")"
    if [ "$ahead" = 0 ]; then gate "pushed" 1 "nothing ahead of $upstream"
    else gate "pushed" 0 "$ahead commit(s) ahead of $upstream; push first"; fi
else
    gate "pushed" 0 "branch $branch has no upstream; push with -u first"
fi
dirty="$(git status --porcelain 2>/dev/null)"
if [ -z "$dirty" ]; then gate "clean-tree" 1 "working tree clean"
else gate "clean-tree" 0 "uncommitted changes: $(printf '%s' "$dirty" | awk '{print $2}' | tr '\n' ' ')"; fi

# --- 2  CI green for HEAD -----------------------------------------------------
ci_detail=""; ci_ok=0
if runs="$(gh run list --commit "$head_sha" -L 20 --json status,conclusion,name --template '{{range .}}{{.status}} {{.conclusion}} {{.name}}{{"\n"}}{{end}}' 2>&1)"; then
    runs="$(printf '%s' "$runs" | sed '/^$/d')"
    if [ -z "$runs" ]; then
        ci_detail="no CI run for HEAD ${head_sha:0:12}; not run counts as red"
    else
        total="$(printf '%s\n' "$runs" | wc -l | tr -d ' ')"
        green="$(printf '%s\n' "$runs" | grep -c '^completed success ' || true)"
        if [ "$green" = "$total" ]; then ci_ok=1; ci_detail="$green of $total run(s) green: $(printf '%s\n' "$runs" | awk '{print $3}' | tr '\n' ' ')"
        else ci_detail="$green of $total run(s) green; the rest: $(printf '%s\n' "$runs" | grep -v '^completed success ' | awk '{print $3 "=" $1 "/" $2}' | tr '\n' ' ')"; fi
    fi
else
    ci_detail="gh run list failed: $(printf '%s' "$runs" | head -1)"
fi
gate "ci-green" "$ci_ok" "$ci_detail"

# --- 3  phase frontmatter agrees with the body line ---------------------------
phases_dir=""
for d in docs/phases phases; do [ -d "$d" ] && { phases_dir="$d"; break; }; done
if [ -z "$phases_dir" ]; then
    gate "phase-status" 0 "neither docs/phases/ nor phases/ exists"
else
    bad=""; n=0
    for f in "$phases_dir"/[0-9]*-*.md; do
        [ -f "$f" ] || continue
        n=$((n + 1))
        fm_status="$("$FM" get "$f" status 2>/dev/null || echo "<missing>")"
        body_status="$(sed -nE 's/^\*\*Status on [0-9]{4}-[0-9]{2}-[0-9]{2}:\*\* *(.*)$/\1/p' "$f" | head -1 | tr '[:upper:]' '[:lower:]')"
        case "$body_status" in
            "not started"*) body_status="not started" ;;
            "in progress"*) body_status="in progress" ;;
            done*) body_status="done" ;;
            *) body_status="<no status line>" ;;
        esac
        [ "$fm_status" = "$body_status" ] || bad="$bad$f (frontmatter '$fm_status', body '$body_status') "
    done
    if [ "$n" = 0 ] && [ -n "${fm[phase]:-}" ]; then gate "phase-status" 0 "$phases_dir/ has no NN-*.md phase file, yet PROGRESS names phase '${fm[phase]}'"
    elif [ "$n" = 0 ]; then gate "phase-status" 1 "no phase file yet, and PROGRESS names none"
    elif [ -n "$bad" ]; then gate "phase-status" 0 "$bad"
    else gate "phase-status" 1 "$n phase file(s) agree with their status lines"; fi
fi

# --- 4  next-session.md, fresh -----------------------------------------------
if [ ! -f docs/next-session.md ]; then
    gate "next-session" 0 "docs/next-session.md does not exist; run tools/next-session.sh"
else
    parent_time="$(git log -1 --format=%ct HEAD~1 2>/dev/null || echo 0)"
    file_time="$(stat -c %Y docs/next-session.md 2>/dev/null || stat -f %m docs/next-session.md)"
    if [ "$file_time" -ge "$parent_time" ]; then gate "next-session" 1 "docs/next-session.md is newer than HEAD's parent"
    else gate "next-session" 0 "docs/next-session.md is older than HEAD's parent; run tools/next-session.sh"; fi
fi

# --- 5  an owner decision has its question -----------------------------------
case "${fm[needs_owner]:-}" in
    true)  if [ -n "${fm[needs_owner_why]:-}" ]; then gate "needs-owner" 1 "needs_owner with a reason"
           else gate "needs-owner" 0 "needs_owner is true but needs_owner_why is empty"; fi ;;
    false) gate "needs-owner" 1 "no owner decision pending" ;;
    *)     gate "needs-owner" 0 "needs_owner must be true or false, not '${fm[needs_owner]:-}'" ;;
esac

# --- 6  the repository's own hooks -------------------------------------------
hooks_run=0
for h in tools/session-close.d/*.sh; do
    [ -e "$h" ] || continue
    hooks_run=$((hooks_run + 1))
    if [ ! -x "$h" ]; then gate "hook:$(basename "$h")" 0 "not executable"; continue; fi
    if out="$("$h" 2>&1)"; then gate "hook:$(basename "$h")" 1 "exit 0"
    else gate "hook:$(basename "$h")" 0 "exit $?: $(printf '%s' "$out" | tail -3 | tr '\n' ' ')"; fi
done
[ "$hooks_run" = 0 ] && printf '  (no repository hooks in tools/session-close.d/)\n'

# --- state.json ---------------------------------------------------------------
mkdir -p "$STATE_DIR"
{
    printf '{\n  "schema": 1,\n'
    printf '  "project": %s,\n' "$(json_str "${fm[project]:-}")"
    printf '  "frontmatter": {'
    first=1
    for key in project status phase phase_status next blocked_on needs_owner needs_owner_why updated; do
        [ "$first" = 1 ] || printf ','
        first=0
        printf '\n    %s: %s' "$(json_str "$key")" "$(json_str "${fm[$key]:-}")"
    done
    printf '\n  },\n'
    printf '  "head": %s,\n  "branch": %s,\n  "head_committed_at": %s,\n' "$(json_str "$head_sha")" "$(json_str "$branch")" "$(json_str "$head_time")"
    printf '  "checked_at": %s,\n  "ok": %s,\n  "failures": %s,\n' "$(json_str "$(date -Iseconds)")" "$([ "$fails" = 0 ] && echo true || echo false)" "$fails"
    printf '  "gates": ['
    for i in "${!gate_names[@]}"; do
        [ "$i" = 0 ] || printf ','
        printf '\n    {"id": %s, "ok": %s, "detail": %s}' "$(json_str "${gate_names[$i]}")" "$([ "${gate_ok[$i]}" = 1 ] && echo true || echo false)" "$(json_str "${gate_detail[$i]}")"
    done
    printf '\n  ]\n}\n'
} >"$STATE"

# --- the verdict --------------------------------------------------------------
if [ "$fails" = 0 ]; then
    echo "session-close: GREEN (${#gate_names[@]} checks); $STATE written"
    exit 0
fi
reasons="$(for i in "${!gate_names[@]}"; do [ "${gate_ok[$i]}" = 1 ] || printf -- '- %s: %s\n' "${gate_names[$i]}" "${gate_detail[$i]}"; done)"
echo "session-close: RED, $fails of ${#gate_names[@]} checks failed; $STATE written"
[ "$hook" = 1 ] || exit 1

# Under the hook: block the stop, with the reasons, unless this turn did
# no work or the session has already been blocked MAX_HOOK_BLOCKS times.
if [ "${tool_use_count:-1}" = 0 ]; then
    echo "session-close: this turn used no tool; not blocking the stop" >&2
    exit 0
fi
counter="$STATE_DIR/session-close/blocks-${session_id:-unknown}"
mkdir -p "$(dirname "$counter")"
blocks="$(cat "$counter" 2>/dev/null || echo 0)"
if [ "$blocks" -ge "$MAX_HOOK_BLOCKS" ]; then
    echo "session-close: still red after $blocks blocks; the stop is allowed and $STATE records the red" >&2
    exit 0
fi
echo $((blocks + 1)) >"$counter"
{
    echo "The session is not closed: tools/session-close.sh is red ($((blocks + 1)) of $MAX_HOOK_BLOCKS). Fix these, then stop again:"
    printf '%s\n' "$reasons"
} >&2
exit 2
