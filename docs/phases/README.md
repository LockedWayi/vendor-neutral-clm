# Phases

The working plan, one file per phase: `NN-short-name.md`, copied from
[PHASE-TEMPLATE.md](PHASE-TEMPLATE.md). Numbers are never reused; a phase
split in two becomes `NNa` and `NNb`.

A phase starts only when every "done when" criterion of the phases it
depends on is green. It is closed by a PR that updates its status line
and frontmatter, the README's status, the threat model's status line and
the CHANGELOG.

## The frontmatter

Each phase file opens with:

```yaml
---
id: "01"
name: signer
status: in progress            # not started | in progress | done
done_on: ""                    # YYYY-MM-DD when status is done
depends_on: []                 # phase ids that must be done first; explicit
---
```

`depends_on` is explicit and required, never inferred from the number.
The number says the order the phases were planned in; `depends_on` says
what must be green before this one starts, and the two differ as soon as
a phase forks: `03a` and `03b` both depend on `02` and not on each other,
and `04` may depend on `03a` alone. An empty list means the phase depends
on nothing, and only the first phase should say so.

The `**Status on YYYY-MM-DD:**` line in the body stays, and the two
are kept in agreement by hand: no check does it here.

| Phase | Goal | Status |
|---|---|---|
| <!-- 01, linked to its file --> | <!-- one line --> | <!-- not started / in progress / done YYYY-MM-DD --> |
