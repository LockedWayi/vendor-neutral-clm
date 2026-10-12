---
id: "NN"
name: short-name
status: not started
done_on: ""
depends_on: []
---

# Phase NN: <name>

**Status on YYYY-MM-DD:** not started | in progress (criteria 1–3 green) | done

<!-- Copy this file to docs/phases/NN-short-name.md. Delete every comment
before the phase starts. The frontmatter is what machines read: `id`
matches the file name's prefix, `status` agrees with the status line
below (kept in agreement by hand), `done_on` is set in
the PR that closes the phase, and `depends_on` lists the ids that must be
done before this one starts; `[]` for a phase that depends on nothing.
It is never inferred from the number: see README.md. -->

## Goal

<!-- One or two sentences: the property the system has when this phase is
done, stated as a fact. Not a list of tasks. -->

## Scope

<!-- What this phase builds or changes. Name packages, scripts, documents. -->

-

## Out of scope

<!-- What a reader might expect here and will not find, each with where it
goes instead (a later phase, a non-goal, a separate repository). A phase
without this section grows. -->

-

## Deliverables

<!-- Each deliverable is a file or a behaviour, and each lands in its own
focused PR where possible. -->

| # | Deliverable | Where |
|---|---|---|
| 1 | | |

## Done when

<!-- Every criterion is checkable by a test or a script, and is written as
the command that proves it with the result that counts as passing. A
criterion that needs judgment is split until it does not. For a refusal,
include the check that it refuses (the mutation: "fails with the guard
removed"). -->

### CI-verified

| # | Criterion | Proved by |
|---|---|---|
| 1 | <!-- e.g. a request without a profile is refused with 400 --> | <!-- `ci/test.sh`, `TestIssue_RefusesARequestWithoutAProfile` --> |
| 2 | Every gate green | `ci/*.sh`, `tools/check-public-links.sh` |

### Maintainer-verified

<!-- Runs CI cannot make: the environment, the version, the command, the
counts. Delete the table if there are none. -->

| # | Criterion | Proved by (environment, command) |
|---|---|---|

## Threat-model sections this phase must update

<!-- Name them. The PR that closes the phase updates each one, or says in
its description why it did not need to. -->

- [ ] Status line
- [ ] §2 Assets: <!-- new or changed rows -->
- [ ] §3 Trust boundaries: <!-- … -->
- [ ] §5 Attackers: <!-- which of A1…An gain or lose what -->
- [ ] §6 Findings: <!-- anything writing this phase found -->
- [ ] §8 What planned work changes: <!-- remove this phase's row -->

## Other documents

- [ ] `docs/architecture.md`: decision records for the choices made
- [ ] `docs/test-matrix.md`: new suites and counts
- [ ] `README.md`: status
- [ ] `CHANGELOG.md`: `[Unreleased]`

## Decisions taken during the phase

<!-- Dated one-liners, each pointing at the decision record or PR that
holds the reasoning. -->
