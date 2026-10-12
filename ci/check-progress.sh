#!/usr/bin/env bash
#
# The progress contract holds: docs/PROGRESS.md has every field, every
# phase file has its frontmatter with an explicit `depends_on`, and each
# phase's frontmatter status agrees with the status line a reader sees.
#
#   ci/check-progress.sh
#
# Where a project stopped lives in exactly one place, docs/PROGRESS.md,
# with a frontmatter the dashboard and tools/session-close.sh read. A
# field that is missing, misspelt or outside its vocabulary is read by a
# machine as "unknown", and unknown is reported as nothing. This gate
# makes it a red check instead.
#
# What it refuses:
#   - no docs/PROGRESS.md, or a frontmatter tools/frontmatter.sh cannot read;
#   - a missing field (project status phase phase_status next blocked_on
#     needs_owner needs_owner_why updated), a value outside its vocabulary,
#     `project` that is not the repository's directory name, `updated`
#     that is not a date;
#   - needs_owner: true with an empty needs_owner_why (an empty or absent
#     needs_owner_options is a warning, not a refusal: free text still works);
#   - a phase (docs/phases/NN-*.md, or phases/NN-*.md) without id, name,
#     status, done_on or depends_on; an id that does not match its file
#     name; a depends_on entry that names no phase file; a `done` phase
#     without done_on, or an unfinished one with it; a `done` phase at or
#     past docs/audits/README.md's audited_from without a passing audit
#     file (docs/audits/NN-*.md, verdict: pass); without that README a
#     done phase is a warning, not a refusal;
#   - a phase whose frontmatter status disagrees with its
#     `**Status on YYYY-MM-DD:**` line, or that has no such line;
#   - PROGRESS naming a phase that has no file, or a phase_status that
#     disagrees with that file; status: active with no phase named once
#     any phase file exists (a fresh project names none until it writes
#     its first).
# It counts what it examined and refuses to report clean over nothing.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
FM="$REPO_ROOT/tools/frontmatter.sh"
PROGRESS="docs/PROGRESS.md"

failures=0; examined=0
fail() { printf '  RED   %s\n' "$*" >&2; failures=$((failures + 1)); }
ok() { examined=$((examined + 1)); }
getf() { "$FM" get "$1" "$2" 2>/dev/null; }

[ -x "$FM" ] || { echo "check-progress: $FM is missing or not executable" >&2; exit 1; }

echo "==> docs/PROGRESS.md"
if [ ! -f "$PROGRESS" ]; then
    fail "$PROGRESS does not exist"
else
    if ! "$FM" keys "$PROGRESS" >/dev/null; then
        fail "$PROGRESS: frontmatter unreadable (see above)"
    else
        declare -A fm
        for key in project status phase phase_status next blocked_on needs_owner needs_owner_why updated; do
            if "$FM" has "$PROGRESS" "$key"; then fm[$key]="$(getf "$PROGRESS" "$key")"; ok
            else fail "$PROGRESS: frontmatter lacks '$key'"; fm[$key]=""; fi
        done
        dirname_here="$(basename "$REPO_ROOT")"
        [ "${fm[project]}" = "$dirname_here" ] || fail "$PROGRESS: project is '${fm[project]}', the directory is '$dirname_here'"
        case "${fm[status]}" in active|parked|abandoned|done) ;; *) fail "$PROGRESS: status '${fm[status]}' is not active|parked|abandoned|done" ;; esac
        case "${fm[phase_status]}" in "not started"|"in progress"|done) ;; *) fail "$PROGRESS: phase_status '${fm[phase_status]}' is not 'not started'|'in progress'|done" ;; esac
        case "${fm[needs_owner]}" in
            true)
                [ -n "${fm[needs_owner_why]}" ] || fail "$PROGRESS: needs_owner is true but needs_owner_why is empty"
                if "$FM" has "$PROGRESS" needs_owner_options; then
                    n_opts="$("$FM" get "$PROGRESS" needs_owner_options | grep -c . || true)"
                    [ "$n_opts" -gt 0 ] || printf '  WARN  %s: needs_owner is true and needs_owner_options is empty; the owner can answer only with free text (D)\n' "$PROGRESS" >&2
                else
                    printf '  WARN  %s: needs_owner is true and there is no needs_owner_options; the owner can answer only with free text (D)\n' "$PROGRESS" >&2
                fi
                ;;
            false) ;;
            *) fail "$PROGRESS: needs_owner '${fm[needs_owner]}' is not true|false" ;;
        esac
        [[ "${fm[updated]}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || fail "$PROGRESS: updated '${fm[updated]}' is not YYYY-MM-DD"
        [ -n "${fm[next]}" ] || fail "$PROGRESS: next is empty"
    fi
fi

phases_dir=""
for d in docs/phases phases; do [ -d "$d" ] && { phases_dir="$d"; break; }; done
declare -A phase_status_of
phase_files=0
if [ -z "$phases_dir" ]; then
    echo "==> no docs/phases/ or phases/ directory"
else
    echo "==> $phases_dir/"
    for f in "$phases_dir"/[0-9]*-*.md; do
        [ -f "$f" ] || continue
        base="$(basename "$f" .md)"
        phase_files=$((phase_files + 1))
        if ! "$FM" keys "$f" >/dev/null; then fail "$f: frontmatter unreadable (see above)"; continue; fi
        for key in id name status done_on depends_on; do
            "$FM" has "$f" "$key" && ok || fail "$f: frontmatter lacks '$key' (depends_on is explicit even when empty: [])"
        done
        id="$(getf "$f" id)"; status="$(getf "$f" status)"; done_on="$(getf "$f" done_on)"
        [ "${base%%-*}" = "$id" ] || fail "$f: id '$id' does not match the file name prefix '${base%%-*}'"
        case "$status" in
            done) [[ "$done_on" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || fail "$f: status is done but done_on is '$done_on', not a date" ;;
            "not started"|"in progress") [ -z "$done_on" ] || fail "$f: status is '$status' but done_on is set ('$done_on')" ;;
            *) fail "$f: status '$status' is not 'not started'|'in progress'|done" ;;
        esac
        phase_status_of["$id"]="$status"
        body="$(sed -nE 's/^\*\*Status on [0-9]{4}-[0-9]{2}-[0-9]{2}:\*\* *(.*)$/\1/p' "$f" | head -1 | tr '[:upper:]' '[:lower:]')"
        case "$body" in
            "not started"*) body="not started" ;; "in progress"*) body="in progress" ;; done*) body="done" ;;
            *) body="" ;;
        esac
        if [ -z "$body" ]; then fail "$f: no '**Status on YYYY-MM-DD:** not started|in progress|done' line in the body"
        elif [ "$body" != "$status" ]; then fail "$f: frontmatter status '$status' but the body line says '$body'"
        else ok; fi
    done
    # depends_on resolves, and does not point at itself.
    for f in "$phases_dir"/[0-9]*-*.md; do
        [ -f "$f" ] || continue
        id="$(getf "$f" id)"
        while IFS= read -r dep; do
            [ -n "$dep" ] || continue
            [ "$dep" != "$id" ] || fail "$f: depends_on names itself"
            [ -n "${phase_status_of[$dep]+x}" ] || fail "$f: depends_on names '$dep', and no $phases_dir/$dep-*.md exists"
        done < <(getf "$f" depends_on)
    done
    # A done phase has an audit (docs/audits/NN-*.md with verdict: pass),
    # from the id docs/audits/README.md names in audited_from on. The rule
    # is opt-in per repository: without the README it is a warning, since
    # phases closed before any auditor existed have no audit to show.
    AUDITS="${AUDITS_DIR:-docs/audits}"
    if [ -f "$AUDITS/README.md" ] && "$FM" has "$AUDITS/README.md" audited_from; then
        from="$(getf "$AUDITS/README.md" audited_from)"
        echo "==> $AUDITS/ (audited from phase $from)"
        for f in "$phases_dir"/[0-9]*-*.md; do
            [ -f "$f" ] || continue
            id="$(getf "$f" id)"
            [ "${phase_status_of[$id]}" = "done" ] || continue
            [ "$(printf '%s\n%s\n' "$from" "$id" | sort -V | head -1)" = "$from" ] || continue
            audit=""
            for a in "$AUDITS/$id-"*.md; do [ -f "$a" ] && { audit="$a"; break; }; done
            if [ -z "$audit" ]; then fail "$f: status is done and $AUDITS/README.md audits from $from, but no $AUDITS/$id-*.md exists (nobetci audit writes it)"
            elif [ "$(getf "$audit" verdict)" != pass ]; then fail "$f: status is done but $audit says verdict '$(getf "$audit" verdict)', not pass"
            else ok; fi
        done
    else
        has_done=0
        for id in "${!phase_status_of[@]}"; do [ "${phase_status_of[$id]}" = "done" ] && has_done=1; done
        [ "$has_done" = 1 ] && printf '  WARN  no %s/README.md with audited_from: done phases are not audited (nobetci audit <project> --phase NN writes the first)\n' "$AUDITS" >&2
    fi
fi

if [ -f "$PROGRESS" ] && [ -n "${fm[phase]+x}" ]; then
    echo "==> PROGRESS against the phase files"
    if [ -n "${fm[phase]}" ]; then
        if [ -z "${phase_status_of[${fm[phase]}]+x}" ]; then
            fail "$PROGRESS: phase '${fm[phase]}' has no ${phases_dir:-docs/phases}/${fm[phase]}-*.md"
        elif [ "${phase_status_of[${fm[phase]}]}" != "${fm[phase_status]}" ]; then
            fail "$PROGRESS: phase_status '${fm[phase_status]}' but ${phases_dir}/${fm[phase]}-*.md says '${phase_status_of[${fm[phase]}]}'"
        else ok; fi
    else
        # No phase named: fine for a project that has not written its first
        # phase file yet; once one exists, an active project must name one.
        if [ "${fm[status]}" = active ] && [ "$phase_files" -gt 0 ]; then
            fail "$PROGRESS: status is active and phase files exist, but no phase is named"
        else ok; fi
    fi
fi

echo
if [ "$failures" -ne 0 ]; then
    echo "check-progress: $failures finding(s); the contract is in docs/BLUEPRINT.md section 12 and docs/phases/README.md" >&2
    exit 1
fi
[ "$examined" -gt 0 ] || { echo "check-progress: examined 0 fields; refusing to report a clean run over nothing" >&2; exit 1; }
echo "check-progress: $examined field(s) and status line(s) examined, every one within the contract"
