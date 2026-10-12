#!/usr/bin/env bash
#
# Fail on any relative link in a tracked Markdown file that points at a
# file which does not exist in the tree.
#
#   tools/check-public-links.sh [<tree>]
#
# The tree defaults to the repository this script lives in. Pass another
# tree to check an export of this one: a link that resolves here can point
# at nothing in a copy with some files removed. The suite gate runs this,
# so a dead link fails the build.
#
# Runs in the pinned tools image, so the host's Python never decides the
# verdict. Anchors (#section) are not checked; external URLs are not
# fetched, because a gate whose verdict depends on a third party's uptime
# fails for reasons unrelated to the change under review.
set -euo pipefail

SCRIPT_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TREE="$(cd "${1:-$SCRIPT_REPO}" && pwd)"
# shellcheck source=ci/pins.sh
. "$SCRIPT_REPO/ci/pins.sh"

# git runs on the host, which has it; the checker reads the list on stdin.
git -C "$TREE" ls-files -z -- '*.md' |
docker run --rm -i -v "$TREE":/tree:ro -w /tree --user "$(id -u):$(id -g)" \
    "$TOOLS_PYTHON_IMAGE" python3 -c '
import os, re, sys
files = [f for f in sys.stdin.buffer.read().decode().split("\0") if f]
if not files:
    sys.exit("check-public-links: no tracked Markdown files; refusing to report a clean run over nothing")
link = re.compile(r"\[([^\]]*)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
fence = re.compile(r"^(```|~~~)")
dead = 0
for f in sorted(files):
    text, in_fence = [], False
    for line in open(f, encoding="utf-8"):
        if fence.match(line.lstrip()):
            in_fence = not in_fence
        # Code blocks and inline code show syntax; they are not links.
        text.append("\n" if in_fence else re.sub(r"`[^`]*`", "", line))
    text = "".join(text)
    for m in link.finditer(text):
        target = m.group(2)
        if re.match(r"^([a-z][a-z0-9+.-]*:|#)", target):
            continue
        path = target.split("#")[0]
        resolved = os.path.normpath(os.path.join(os.path.dirname(f), path))
        if not os.path.exists(resolved):
            line = text[: m.start()].count("\n") + 1
            print(f"{f}:{line}: [{m.group(1)}]({target}) -> missing {resolved}")
            dead += 1
if dead:
    sys.exit(f"check-public-links: {dead} relative link(s) point at files that do not exist")
print(f"check-public-links: every relative link in {len(files)} Markdown files resolves")
'
