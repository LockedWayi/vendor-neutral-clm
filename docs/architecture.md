# Architecture

This document explains the shape of the system and the reasoning behind
the major choices. It answers "why is it built this way". What it
protects and from whom is in [threat-model.md](threat-model.md).

---

## What this is, in one paragraph

<!-- The whole system in one paragraph a newcomer can hold in their head:
the core, what is built on it, how it runs, how it ships. Name what is
planned as planned. -->

## What this is not

<!-- Scope stated up front: the features the design rules out, so nobody
asks for them. -->

---

## The core idea

<!-- The one abstraction or property everything else depends on, with a
diagram if it helps. Say which parts are built, which run in CI, and which
only run in the maintainer's environment:

```
            callers
               │
        one interface            ← the abstraction
     ┌─────────┼─────────┐
  impl A     impl B    impl C    ← implementations
  ✅ built   ✅ built   ○ planned
  (CI runs) (local only)
```
-->

### <External system>, as measured

<!-- One subsection per external implementation the core has been run
against: version, date, conditions, what differed and how the difference
was absorbed (a stricter shared path, or a declaration the suite asserts),
and what was NOT measured. Delete until there is one. -->

---

## The layering, and why it is ordered this way

Each layer is proven before the next is added, so the security-critical
surface is never large and untested at once.

1. **<Layer 1>.** <!-- What it is, and why it comes first. -->
2. **<Layer 2>.** <!-- … -->

<!-- Mark each layer built / in progress / planned / optional, with the
date a plan changed if it did. docs/phases/ holds the working plan; this
list holds the reasoning. -->

---

## Key design decisions

<!-- One record per decision that had a real alternative. Keep rejected
alternatives: a decision recorded without them gets reopened. Record a
reversal with its date instead of deleting the old record. Shape:

### <Chosen thing> rather than <main alternative>
Rejected: <alternative>, because <the real reason it lost>. <Another
alternative>, because <…>. Chosen: <what was done>. Reason: <why>. The
cost: <what this choice costs, stated>.
-->

### Standard-library cryptography only
Rejected: third-party crypto convenience libraries. Chosen: the language's
standard library for primitives and randomness. Reason: importing an
unaudited crypto helper undercuts a project that claims to be careful.
The cost: some conveniences are written out by hand, over audited
primitives. A dependency that changes this needs its own record here.

### Fail closed, enforcement server-side
Every ambiguous security decision rejects rather than degrades, and every
client-side component is untrusted. Reason: a system that refuses and
says why costs a retry; one that guesses costs an incident. Any client
can be decompiled, so trusting one is a design error.

### Every gate is a script, run the same way locally and in CI
Rejected: logic inline in workflow YAML. Chosen: one script per gate under
`ci/`, with the language half in `ci/lang/`, every tool in a pinned
container. Reason: a red check nobody can reproduce locally gets retried
instead of read. The cost: Docker on every workstation.

---

## Scalability and production-readiness notes

<!-- What would change at 10x and 100x, and what is deliberately not built
yet. Label each item planned, documented-design, or out of scope. -->
