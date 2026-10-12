# Threat model

This document states what this system protects, from whom, and what it
does not protect against. It is written for someone who knows security
but not this codebase. Every claim about what an attacker cannot do is
traceable to a specific mechanism in the code or a test that fails if the
claim breaks. Every claim that is not yet true is labelled as such.

**Status on 2026-10-12.** The project is a skeleton: one package, its
tests, and the pipeline's gates. It has no network surface, no stored
data and no credentials. §8 says what planned work changes.

<!-- Update this line in the same PR as any change it describes:
"**Status on YYYY-MM-DD.** The system has X, Y and Z. It has no A and
no B." -->

---

## 1. How to read this

A threat model is only useful if it distinguishes three things:

- **What an attacker gains.** The concrete capability, not the label.
  "Gets the database password" is a label. "Can read and rewrite every
  customer record until the password is rotated and every session that
  used it is closed" is a capability.
- **What it costs to recover.** Compromises that differ only in recovery
  cost are different compromises.
- **What the attacker still cannot do.** This is the part that justifies
  the design. If compromising one component yields everything, the
  boundaries bought nothing.

Labels used below: **not yet true** (claimed as a goal, not implemented),
**planned** (scheduled in `docs/phases/`), **documented-design** (designed
here, not built or run).

---

## 2. Assets

Ordered by what their loss costs.

| Asset | Where it lives | Loss means |
|---|---|---|
| Source repository and its history | GitHub, `main` protected | An attacker's change reaches whatever the pipeline publishes. See A-repo in §5. |
| <!-- key, credential, dataset, signing identity… --> | <!-- the exact place: token, env var by name, table --> | <!-- the concrete capability an attacker gains, and for how long --> |

<!-- Also list what is NOT an asset because the design prevents it from
existing (e.g. "a secret in a config file: config carries the name of an
environment variable, never a value"). -->

---

## 3. Trust boundaries

<!-- A diagram of the boundaries (B1…Bn) and, for each, what enforces it.
Say which boundaries are enforced structurally (a process cannot name
what is on the other side, and a test fails if that changes) and which by
a check performed on request (which can be deleted or bypassed). -->

---

## 4. Attacker classes

| | Attacker | Assumed capability |
|---|---|---|
| **A1** | <!-- Unauthenticated network client --> | <!-- … --> |
| **A-repo** | Writer to this source repository | Can push a branch and merge it to `main` once the required checks pass. Whether PR review is required: <!-- state it as configured --> |

---

## 5. What each attacker gets, and does not

### A1: <name>

**Gets:** <!-- concrete capabilities, each with the mechanism that
bounds it -->

**Does not get:** <!-- each item traceable to a function, a missing
config field, or a test name -->

**Recovery:** <!-- steps, and their cost -->

**Limit:** <!-- what this system does not defend at this layer, said
plainly -->

### A-repo: Writer to this source repository

**Assumed capability, as the controls stand on 2026-10-12.** <!-- Read the
branch protection back from the API and state it: required checks,
enforce_admins, force-push, deletion, review. -->

**Gets:** any change that passes the required checks. The checks read the
tree the attacker wrote.

**Does not get:** <!-- what stays out of reach: secrets held outside the
repository, anchors in another repository, keys on hardware. -->

**Recovery:** revert the merge. <!-- and what was published meanwhile -->

---

## 6. Findings this model produced

<!-- Writing this document is a review. Record what it found: the defect,
how it was found, what was fixed, what residual was accepted, and the
options considered ("Two options: 1. … 2. … The residual is accepted.").
Number them 6.1, 6.2, … -->

---

## 7. Non-goals

A threat model that claims everything is defended is not a threat model:

- <!-- e.g. Availability and DoS resistance, beyond what is listed in §6. -->
- <!-- e.g. Defending against a malicious dependency: scanned, not proven. -->

---

## 8. What planned work changes

| Work | Changes for this model |
|---|---|
| <!-- phase or feature --> | <!-- which rows and attackers move, and which boundaries do not --> |

---

## 9. Cross-references

- Design reasoning: [architecture.md](architecture.md)
- What is tested where: [test-matrix.md](test-matrix.md)
- Operator procedures and recovery: [runbook.md](runbook.md)
