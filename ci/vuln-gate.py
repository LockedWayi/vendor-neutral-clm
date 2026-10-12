"""Apply and police the one vulnerability allowlist, ci/vuln-allowlist.yaml.

Run through ci/pins.sh's toolsPython, standard library only:

  vuln-gate.py validate      <allowlist.json>
  vuln-gate.py trivy-hits    <allowlist.json> <trivy.json> <hits-out.json> <scanner>
  vuln-gate.py filter        <allowlist.json> <format> <report> <hits-out.json> <scanner>
  vuln-gate.py require-used  <allowlist.json> <expected-scanners,comma,separated> <hits.json>...

The allowlist reaches this script as JSON (ci/pins.sh's allowlistJSON), so
the YAML stays in trivy's own schema, which trivy reads natively as an
--ignorefile, and nothing here needs a YAML parser.

Why one script with four verbs. trivy applies the allowlist itself; the
language scanners (govulncheck, pip-audit) do not read it, so `filter`
applies the same entries to their reports. Each scanner then records which
entries it used, and `require-used` judges the union: an entry that
suppressed nothing in any scanner is an exception nobody reviews, and from
outside it is indistinguishable from a clean scan. No single scanner can
make that call, because an entry may cover a finding only one of them sees.
"""

import datetime
import json
import sys

MAX_DAYS = 180


def entries_n(n):
    return f"{n} entr{'y' if n == 1 else 'ies'}"


def die(msg):
    print(f"vuln-gate: {msg}", file=sys.stderr)
    sys.exit(1)


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def entries(allowlist_path):
    doc = load(allowlist_path)
    if not isinstance(doc, dict) or "vulnerabilities" not in doc:
        die(f"{allowlist_path}: expected a top-level 'vulnerabilities' list")
    items = doc["vulnerabilities"] or []
    if not isinstance(items, list):
        die("'vulnerabilities' must be a list")
    return items


def validate(allowlist_path):
    today = datetime.date.today()
    limit = today + datetime.timedelta(days=MAX_DAYS)
    problems = []
    seen = set()
    items = entries(allowlist_path)
    for n, e in enumerate(items, 1):
        where = f"entry {n}"
        if not isinstance(e, dict):
            problems.append(f"{where}: not a mapping")
            continue
        vid = str(e.get("id") or "").strip()
        if not vid:
            problems.append(f"{where}: no id")
        elif vid in seen:
            problems.append(f"{where}: {vid} is listed twice")
        seen.add(vid)
        where = f"{where} ({vid or '?'})"
        statement = str(e.get("statement") or "").strip()
        if not statement:
            problems.append(f"{where}: no statement; say why this finding does not apply here")
        elif statement.lower().rstrip(".") in {"false positive", "not applicable", "n/a", "accepted"}:
            problems.append(
                f"{where}: statement '{statement}' is a verdict, not a reason; say what makes it one here"
            )
        raw = e.get("expired_at")
        if not raw:
            problems.append(f"{where}: no expired_at; an exception nobody has to renew is a forgotten one")
            continue
        try:
            expiry = datetime.date.fromisoformat(str(raw)[:10])
        except ValueError:
            problems.append(f"{where}: expired_at '{raw}' is not YYYY-MM-DD")
            continue
        if expiry <= today:
            problems.append(f"{where}: expired on {expiry}; upgrade, or write a new reason and a new date")
        elif expiry > limit:
            problems.append(f"{where}: expired_at {expiry} is more than {MAX_DAYS} days out (limit {limit})")
    if problems:
        for p in problems:
            print(f"  REFUSED  {p}", file=sys.stderr)
        die(f"{len(problems)} problem(s) in the allowlist")
    print(f"vuln-gate: {entries_n(len(items))} in the allowlist, each with an id, a reason and an expiry")


def write_hits(path, scanner, used):
    with open(path, "w", encoding="utf-8") as f:
        json.dump({"scanner": scanner, "used": sorted(used)}, f, indent=2)
        f.write("\n")


def trivy_hits(allowlist_path, report_path, hits_out, scanner):
    ids = {str(e.get("id")) for e in entries(allowlist_path)}
    report = load(report_path)
    used = set()
    for result in report.get("Results") or []:
        for mf in result.get("ExperimentalModifiedFindings") or []:
            finding = mf.get("Finding") or {}
            names = {finding.get("VulnerabilityID")} | set(finding.get("VendorIDs") or [])
            used |= ids & {n for n in names if n}
    write_hits(hits_out, scanner, used)
    print(f"vuln-gate: {scanner} used {len(used)} of {len(ids)} allowlist entries")


def json_stream(text):
    """govulncheck -format json writes a stream of objects, not an array."""
    dec = json.JSONDecoder()
    i, n = 0, len(text)
    while i < n:
        while i < n and text[i].isspace():
            i += 1
        if i >= n:
            break
        obj, i = dec.raw_decode(text, i)
        yield obj


def findings_govulncheck(path):
    """Reachable findings only: a trace whose first frame names a function."""
    with open(path, encoding="utf-8") as f:
        text = f.read()
    aliases, reachable = {}, {}
    saw_config = False
    for msg in json_stream(text):
        if "config" in msg:
            saw_config = True
        if "osv" in msg and isinstance(msg["osv"], dict):
            osv = msg["osv"]
            aliases[osv["id"]] = set(osv.get("aliases") or [])
        if "finding" in msg:
            fnd = msg["finding"]
            trace = fnd.get("trace") or []
            if trace and trace[0].get("function"):
                frame = trace[0]
                reachable[fnd["osv"]] = (
                    f"{frame.get('package', frame.get('module', '?'))}.{frame['function']}"
                )
    if not saw_config:
        die(f"{path} has no govulncheck config message; the scan did not run")
    return [{"id": i, "aliases": sorted(aliases.get(i, set())), "detail": d} for i, d in reachable.items()]


def findings_pip_audit(path):
    report = load(path)
    if "dependencies" not in report:
        die(f"{path} has no 'dependencies'; the scan did not run")
    # pip-audit can list one advisory more than once for a distribution
    # (measured on 2.10.1); keyed by (distribution, id) it is one finding.
    out = {}
    for dep in report["dependencies"]:
        for v in dep.get("vulns") or []:
            fixes = ", ".join(v.get("fix_versions") or []) or "none released"
            detail = f"{dep['name']} {dep.get('version', '?')} (fix: {fixes})"
            key = (dep["name"], v["id"])
            out[key] = {"id": v["id"], "aliases": sorted(v.get("aliases") or []), "detail": detail}
    print(f"vuln-gate: pip-audit examined {len(report['dependencies'])} installed distributions")
    return list(out.values())


FORMATS = {"govulncheck": findings_govulncheck, "pip-audit": findings_pip_audit}


def filter_findings(allowlist_path, fmt, report_path, hits_out, scanner):
    if fmt not in FORMATS:
        die(f"unknown format {fmt}; known: {', '.join(sorted(FORMATS))}")
    ids = {str(e.get("id")) for e in entries(allowlist_path)}
    used, blocking = set(), []
    for f in FORMATS[fmt](report_path):
        names = {f["id"], *f["aliases"]}
        hit = ids & names
        if hit:
            used |= hit
        else:
            blocking.append(f)
    write_hits(hits_out, scanner, used)
    if blocking:
        for f in blocking:
            print(
                f"  FINDING  {f['id']} ({', '.join(f['aliases']) or 'no aliases'}): {f['detail']}",
                file=sys.stderr,
            )
        die(f"{scanner}: {len(blocking)} finding(s) not covered by ci/vuln-allowlist.yaml")
    print(f"vuln-gate: {scanner} clean after the allowlist ({entries_n(len(used))} used)")


def require_used(allowlist_path, expected, hits_paths):
    ids = {str(e.get("id")) for e in entries(allowlist_path)}
    reported, used = set(), set()
    for p in hits_paths:
        h = load(p)
        reported.add(h["scanner"])
        used |= set(h["used"])
    missing = [s for s in expected if s not in reported]
    if missing:
        die(f"no hits file from {', '.join(missing)}; a union missing a scanner is not a union")
    unused = sorted(ids - used)
    if unused:
        for u in unused:
            print(f"  UNUSED   {u}: suppressed nothing in {', '.join(sorted(reported))}", file=sys.stderr)
        die(f"{entries_n(len(unused))} suppressed nothing; remove them")
    scanners = ", ".join(sorted(reported))
    print(f"vuln-gate: all {entries_n(len(ids))} in force suppressed something (scanners: {scanners})")


# verb -> (function, minimum arguments, maximum arguments or None)
VERBS = {
    "validate": (validate, 1, 1),
    "trivy-hits": (trivy_hits, 4, 4),
    "filter": (filter_findings, 5, 5),
    "require-used": (
        lambda allowlist, expected, *hits: require_used(
            allowlist, [x for x in expected.split(",") if x], hits
        ),
        3,
        None,
    ),
}


def main(argv):
    verb, args = (argv[1], argv[2:]) if len(argv) > 1 else ("", [])
    if verb not in VERBS:
        die(f"unknown verb '{verb}'\n{__doc__}")
    fn, lo, hi = VERBS[verb]
    if len(args) < lo or (hi is not None and len(args) > hi):
        die(f"bad usage: {' '.join(argv[1:])}\n{__doc__}")
    fn(*args)


if __name__ == "__main__":
    main(sys.argv)
