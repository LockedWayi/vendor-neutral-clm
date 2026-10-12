#!/usr/bin/env bash
#
# Render docs/next-session.md, the paste-ready prompt a fresh session
# starts from, out of docs/PROGRESS.md.
#
#   tools/next-session.sh [--out <file>] [--template <file>]
#
# A session is handed over, not resumed: `claude --continue` reloads the
# whole old context, and a context that has been compacted once has
# already lost what it was compacted over. The prompt carries what the
# next session needs and nothing else: the frontmatter's `next` and
# `blocked_on`, the pending owner decision, the "Open decisions" section
# of PROGRESS, and the three files to read first. It ends with the rule
# that bounds the session from inside, so a session hands over early
# instead of compacting.
#
# The text is the built-in template below unless `--template` or
# `tools/next-session.tmpl` gives another one (a project in another
# language, say). Placeholders: {{project}}, {{path}}, {{phase}},
# {{phase_status}}, {{phase_file}}, {{next}}, {{blocked_on}},
# {{owner_block}}, {{open_decisions}}, {{date}}, {{budget}},
# {{section:<Heading>}} for the body of any `## <Heading>` of PROGRESS,
# and the raw values {{blocked_on_raw}}, {{needs_owner}},
# {{needs_owner_why}}, {{needs_owner_options}} for a template that words
# them itself.
#
# Refuses: a PROGRESS without the contract's fields, a `phase` with no
# phase file, and a frontmatter the reader cannot parse. It never guesses
# a value.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FM="$REPO_ROOT/tools/frontmatter.sh"
PROGRESS="$REPO_ROOT/docs/PROGRESS.md"
out="$REPO_ROOT/docs/next-session.md"
template=""
budget="${NEXT_SESSION_TOOL_BUDGET:-40}"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --out) out="${2:?--out needs a file}"; shift 2 ;;
        --template) template="${2:?--template needs a file}"; shift 2 ;;
        -h|--help) sed -n '6p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
        *) echo "next-session: unknown argument $1" >&2; exit 2 ;;
    esac
done
[ -n "$template" ] || { [ -f "$REPO_ROOT/tools/next-session.tmpl" ] && template="$REPO_ROOT/tools/next-session.tmpl"; } || true
[ -f "$PROGRESS" ] || { echo "next-session: $PROGRESS does not exist" >&2; exit 1; }

get() { "$FM" get "$PROGRESS" "$1"; }
for key in project status phase phase_status next blocked_on needs_owner needs_owner_why updated; do
    "$FM" has "$PROGRESS" "$key" || { echo "next-session: docs/PROGRESS.md frontmatter lacks '$key'" >&2; exit 1; }
done
project="$(get project)"; phase="$(get phase)"; phase_status="$(get phase_status)"
next="$(get next)"; blocked_on="$(get blocked_on)"
needs_owner="$(get needs_owner)"; needs_owner_why="$(get needs_owner_why)"

# The phase file: docs/phases/ by default; a repository that keeps its
# phases at the root (phases/) is accepted, and the choice is reported.
phases_dir=""
for d in docs/phases phases; do [ -d "$REPO_ROOT/$d" ] && { phases_dir="$d"; break; }; done
phase_file=""
if [ -n "$phase" ]; then
    [ -n "$phases_dir" ] || { echo "next-session: phase '$phase' named but neither docs/phases/ nor phases/ exists" >&2; exit 1; }
    for f in "$REPO_ROOT/$phases_dir/$phase"-*.md; do [ -f "$f" ] && phase_file="$phases_dir/$(basename "$f")" && break; done
    [ -n "$phase_file" ] || { echo "next-session: no file $phases_dir/$phase-*.md for phase '$phase'" >&2; exit 1; }
fi

# The "Open decisions" section of the body, verbatim, up to the next
# heading of the same or a higher level.
# section <heading>: the body of PROGRESS's `## <heading>` up to the next
# heading of the same or a higher level. HTML comments are the template's
# guidance to the writer, not content, and are dropped.
section() {
awk -v H="$1" '
    /^## / { if (on) exit; if (substr($0, 4) == H) { on = 1; next } }
    on { print }
' "$PROGRESS" | awk '
    { line = $0
      while (1) {
        if (inc) { e = index(line, "-->"); if (!e) { line = ""; break } line = substr(line, e + 3); inc = 0 }
        s = index(line, "<!--"); if (!s) break
        e = index(substr(line, s), "-->")
        if (e) line = substr(line, 1, s - 1) substr(line, s + e + 2); else { line = substr(line, 1, s - 1); inc = 1; break }
      }
      if (line ~ /[^ \t]/) print line
    }'
}
open_decisions="$(section "Open decisions")"
[ -n "$open_decisions" ] || open_decisions="- none recorded in docs/PROGRESS.md"

owner_block=""
needs_owner_options=""
if "$FM" has "$PROGRESS" needs_owner_options; then
    needs_owner_options="$("$FM" get "$PROGRESS" needs_owner_options | sed '/^$/d')"
fi
case "$needs_owner" in
    true) [ -n "$needs_owner_why" ] || { echo "next-session: needs_owner is true but needs_owner_why is empty" >&2; exit 1; }
          owner_block="Owner decision pending: $needs_owner_why"
          [ -z "$needs_owner_options" ] || owner_block="$owner_block
Options:
$needs_owner_options"
          owner_block="$owner_block
Do not take it. Ask me, with options, and stop if the work cannot continue without it."
          ;;
    false) owner_block="Owner decision pending: none." ;;
    *) echo "next-session: needs_owner must be true or false, not '$needs_owner'" >&2; exit 1 ;;
esac
blocked_on_raw="$blocked_on"
[ -n "$blocked_on" ] || blocked_on="nothing"
phase_line="\`$phase_file\` (phase $phase, $phase_status)"
[ -n "$phase_file" ] || phase_line="no phase file: the frontmatter names no phase"

render_builtin() {
cat <<TEMPLATE
# Next session

Paste this into a fresh \`claude\` session in \`{{project}}\`. It is
rendered by \`tools/next-session.sh\` from \`docs/PROGRESS.md\`; change
PROGRESS and rerun, do not edit this file. Rendered {{date}}.

---

I am the owner of {{project}}. Work in {{path}} on a branch off
\`main\`, one focused PR per change, as \`CLAUDE.md\` and
\`docs/BLUEPRINT.md\` say. Work autonomously; ask me only for a decision
that is mine to take, as a multiple-choice question.

Read first:

1. \`CLAUDE.md\`
2. \`docs/PROGRESS.md\`
3. {{phase_file}}

Start with: {{next}}

Blocked on: {{blocked_on}}.

{{owner_block}}

Open decisions (from \`docs/PROGRESS.md\`):

{{open_decisions}}

Stop and close when the current deliverable lands, or after about
{{budget}} tool calls, whichever comes first. Closing means: update
\`docs/PROGRESS.md\` (frontmatter \`updated\` is today, \`next\` is the
first thing the next session does), run \`tools/next-session.sh\`,
commit, push, wait for CI, and finish with \`tools/session-close.sh\`
exiting 0. The session is not over while it exits 1.
TEMPLATE
}

if [ -n "$template" ]; then text="$(cat "$template")"; else text="$(render_builtin)"; fi

# Substitution without sed, so a value is never read as an expression.
subst() {
    local key="$1" val="$2"
    text="${text//"{{$key}}"/$val}"
}
subst project "$project"
subst path "$REPO_ROOT"
subst phase "$phase"
subst phase_status "$phase_status"
subst phase_file "$phase_line"
subst next "$next"
subst blocked_on "$blocked_on"
subst blocked_on_raw "$blocked_on_raw"
subst owner_block "$owner_block"
subst needs_owner "$needs_owner"
subst needs_owner_why "$needs_owner_why"
subst needs_owner_options "$needs_owner_options"
subst open_decisions "$open_decisions"
subst date "$(date +%F)"
subst budget "$budget"
# {{section:Heading}}: any other section of PROGRESS a template asks for.
while IFS= read -r ph; do
    [ -n "$ph" ] || continue
    heading="${ph#\{\{section:}"; heading="${heading%\}\}}"
    body="$(section "$heading")"
    [ -n "$body" ] || { echo "next-session: the template asks for section '$heading' and docs/PROGRESS.md has no such ## heading, or it is empty" >&2; exit 1; }
    text="${text//"$ph"/$body}"
done < <(printf '%s' "$text" | grep -o '{{section:[^}]*}}' | sort -u)
if [[ "$text" == *'{{'* ]]; then
    echo "next-session: a placeholder is left unrendered: $(printf '%s' "$text" | grep -o '{{[^}]*}}' | sort -u | tr '\n' ' ')" >&2
    exit 1
fi

mkdir -p "$(dirname "$out")"
printf '%s\n' "$text" >"$out"
echo "next-session: wrote ${out#"$REPO_ROOT"/} from docs/PROGRESS.md (phase ${phase:-none}, ${phase_status})"
