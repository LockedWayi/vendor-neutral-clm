# Test matrix: what runs where, and what a new backend must provide

<!-- A "backend" is any external implementation the core drives through
one interface: a database engine, a cloud API, a device, a vendor module.
If the project has exactly one and always will, keep §3, §4 and §6 and
say so in §1. -->

Every test that touches a backend runs against every backend the
environment provides. This document is the inventory behind that rule:
what is being proved, where it lives, and what a backend has to supply
before it can join.

---

## 1. Why more than one backend, in one paragraph

<!-- The concrete defect a single implementation hid, once there is one.
Until then: an abstraction exercised against one implementation is a
guess, and its shape silently encodes that implementation. -->

---

## 2. The harness

<!-- How a test asks for a backend (one registry, one ForEach), and the
properties that matter:
- Skip policy: no configuration → skip with a message; partial
  configuration → fail, naming what is missing.
- Run-scoped names for anything that persists on the backend, so a run
  does not collide with its own previous run.
- Cleanup that destroys what a run created, and a separate operator tool
  for older litter. -->

---

## 3. What runs on every backend today

| Suite | Tests | Proves |
|---|---:|---|
| <!-- package or path --> | <!-- n --> | <!-- the contract it checks --> |

**<n>** per-backend tests in total, measured <!-- YYYY-MM-DD, where -->,
with:

```sh
# the exact command that produced the count
```

---

## 4. What does not multiply

These touch no backend, so running them per backend would cost time and
prove nothing:

- `internal/version` / `src/…/__init__.py`: the build's identification.

---

## 5. Adding a backend

What a backend must provide before it can join the registry: an adapter,
one registry entry, the environment variables it reads, and its
declarations.

### Declared capabilities

<!-- One field per behaviour on which two conforming backends have been
seen to differ. The suite measures every field in both directions: a
backend that declares a refusal and then complies fails, and one that
declares compliance and then refuses fails. A field that reads "not
measured" is declared conservatively and its measurement skips with that
reason.

| Field | Backend A x.y | Backend B x.y |
|---|---|---|
| … | measured value (date) | not measured |
-->

### Expected divergences to look for

<!-- Behaviours where backends have disagreed: what to check on a new
one, and the measured value per backend. "Not measured" means exactly
that. Correct a wrong row visibly: ~~old claim~~ Measured YYYY-MM-DD: …

| Behaviour | What to check | Backend, measured |
|---|---|---|
-->

---

## 6. Running it

```sh
ci/test.sh        # every backend this environment provides; the rest skip
```

<!-- The per-backend environment variables, and the one command that runs
every configured backend in one invocation. Every measured run disables
result caches, because a replayed result never touched the backend. Report
counts as pass / skip / fail per backend. -->
