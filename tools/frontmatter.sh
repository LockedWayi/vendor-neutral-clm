#!/usr/bin/env bash
#
# Read one key out of a Markdown file's YAML frontmatter, with bash and
# awk alone.
#
#   tools/frontmatter.sh get  <file> <key>   # the value; a list prints one item per line
#   tools/frontmatter.sh has  <file> <key>   # exit 0 if the key is present
#   tools/frontmatter.sh keys <file>         # every key, one per line
#
# The frontmatter contract (docs/PROGRESS.md, docs/phases/NN-*.md) is a
# flat mapping: scalars, folded scalars (`>-`), quoted strings, inline
# lists (`[]`, `["01", "02"]`) and block lists (`- item`). That is all this
# reads, and all the contract allows, so a YAML parser is not needed and
# none is pinned. A nested mapping, an anchor or a multi-document file is
# refused, not guessed at.
#
# Exit 1 when the key is absent, 2 when the file has no frontmatter or the
# frontmatter has a shape outside the contract, with the reason on stderr.
set -euo pipefail

usage() { sed -n '6,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2; exit 2; }
[ "$#" -ge 2 ] || usage
mode="$1"; file="$2"; key="${3:-}"
case "$mode" in get|has) [ -n "$key" ] || usage ;; keys) ;; *) usage ;; esac
[ -f "$file" ] || { echo "frontmatter: $file: no such file" >&2; exit 2; }

# The parser prints "KEY<TAB>VALUE" lines; a list prints one line per item
# with the same key. A scalar prints exactly one line, an empty list none,
# so `has` and `keys` need the key list separately: those are printed with
# a leading tab.
parse() {
    awk -v FILE="$file" '
    function strip_comment(s,    q, i, c) {
        q = ""
        for (i = 1; i <= length(s); i++) {
            c = substr(s, i, 1)
            if (q != "") { if (c == q) q = ""; continue }
            if (c == "\"" || c == "\047") { q = c; continue }
            if (c == "#" && (i == 1 || substr(s, i-1, 1) ~ /[ \t]/)) return substr(s, 1, i-1)
        }
        return s
    }
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function unquote(s) {
        s = trim(s)
        if (s ~ /^".*"$/ || s ~ /^\047.*\047$/) s = substr(s, 2, length(s) - 2)
        return s
    }
    function flush() {
        if (cur == "") return
        if (kind == "fold") { gsub(/\n/, " ", acc); print cur "\t" trim(acc) }
        else if (kind == "keep") { sub(/\n$/, "", acc); gsub(/\n/, "\\n", acc); print cur "\t" acc }
        else if (kind == "blocklist") { if (acc == "" && !seen) printf "" }
        cur = ""; kind = ""; acc = ""; seen = 0
    }
    NR == 1 { if ($0 != "---") { print "frontmatter: " FILE ": no frontmatter (line 1 is not ---)" > "/dev/stderr"; done = 1; exit 2 } next }
    /^---[ \t]*$/ { flush(); done = 1; exit 0 }
    /^\.\.\.[ \t]*$/ { print "frontmatter: " FILE ": multi-document YAML is outside the contract" > "/dev/stderr"; exit 2 }
    {
        line = $0
        if (line ~ /^[ \t]/ || line ~ /^$/) {
            # a continuation: block scalar, block list item, or blank
            if (kind == "fold" || kind == "keep") {
                t = line; sub(/^[ \t]+/, "", t)
                acc = acc t "\n"; next
            }
            if (kind == "blocklist") {
                t = strip_comment(line); t = trim(t)
                if (t == "") next
                if (t ~ /^- /) { print cur "\t" unquote(substr(t, 3)); seen = 1; next }
                print "frontmatter: " FILE ": line " NR " is not a list item under " cur > "/dev/stderr"; exit 2
            }
            if (line ~ /^[ \t]*$/) next
            print "frontmatter: " FILE ": line " NR " is indented but belongs to no block (nested mappings are outside the contract)" > "/dev/stderr"; exit 2
        }
        flush()
        if (line !~ /^[A-Za-z_][A-Za-z0-9_-]*:([ \t]|$)/) {
            print "frontmatter: " FILE ": line " NR " is not `key: value`" > "/dev/stderr"; exit 2
        }
        k = line; sub(/:.*$/, "", k)
        v = line; sub(/^[^:]*:[ \t]?/, "", v)
        v = strip_comment(v); v = trim(v)
        print "\t" k
        cur = k
        if (v == ">" || v == ">-") { kind = "fold"; acc = ""; next }
        if (v == "|" || v == "|-") { kind = "keep"; acc = ""; next }
        if (v == "") { kind = "blocklist"; acc = ""; next }
        if (v ~ /^\[.*\]$/) {
            inner = substr(v, 2, length(v) - 2); inner = trim(inner)
            if (inner != "") {
                n = split(inner, items, ",")
                for (i = 1; i <= n; i++) print k "\t" unquote(items[i])
            }
            cur = ""; next
        }
        if (v ~ /^[&*{]/) { print "frontmatter: " FILE ": line " NR " uses an anchor, alias or flow mapping, outside the contract" > "/dev/stderr"; exit 2 }
        print k "\t" unquote(v)
        cur = ""
    }
    END { if (!done) { print "frontmatter: " FILE ": frontmatter never closed with ---" > "/dev/stderr"; exit 2 } }
    ' "$file"
}

out="$(parse)" || exit $?
case "$mode" in
    keys) printf '%s\n' "$out" | awk -F'\t' '$1 == "" { print $2 }' ;;
    has)  printf '%s\n' "$out" | awk -F'\t' -v k="$key" '$1 == "" && $2 == k { f = 1 } END { exit !f }' ;;
    get)
        printf '%s\n' "$out" | awk -F'\t' -v k="$key" '$1 == "" && $2 == k { f = 1 } END { exit !f }' ||
            { echo "frontmatter: $file: no key '$key'" >&2; exit 1; }
        printf '%s\n' "$out" | awk -F'\t' -v k="$key" '$1 == k { print substr($0, length(k) + 2) }'
        ;;
esac
