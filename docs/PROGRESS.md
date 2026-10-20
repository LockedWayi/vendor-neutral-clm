---
project: vendor-neutral-clm
status: active
phase: ""                      # set to "01" when docs/phases/01-*.md exists
phase_status: not started
next: >-
  Create the public GitHub repository and protect main; then write
  docs/architecture.md's one paragraph and docs/phases/01-inventory.md
  from the decisions of 2026-10-20.
blocked_on: ""
needs_owner: false
needs_owner_why: ""
needs_owner_options: []        # when needs_owner: "A) …", "B) …", one line each; the recommended one ends "(recommended: <why>)"
updated: 2026-10-20
---

# Progress

Where this project stopped, and where the next session starts. The
frontmatter keeps the blueprint's shape for a reader who knows it; no
program reads it here. Every status is backed by the command named
beside it, or says "not run".

## Start here

1. Read `CLAUDE.md`, `docs/BLUEPRINT.md`, `docs/phases/README.md` and
   the phase named in the frontmatter.
2. Read "Now" and "Next" below, then the latest `docs/learning-log/`
   entry.
3. Run every gate once (`CONTRIBUTING.md`); all exit 0 on a fresh
   project.

## Now

<!-- The phase in progress and each of its deliverables with its status:
done / partial / not started, with the command or PR that proves it. -->

| Deliverable | Status | Evidence |
|---|---|---|
| Phase 01 file | not started | no `docs/phases/01-*.md` yet |

## Next

<!-- What the next session does first, then what follows. The first line
is the frontmatter's `next`, written out. -->

1. The owner creates `LockedWayi/vendor-neutral-clm` as a public
   repository, pushes `main` and protects it with the job names from
   `.github/workflows/ci.yml`, `enforce_admins` on (decision 6). Until
   then the README's branch-protection sentence is **not yet true**.
2. Write `docs/architecture.md`'s one paragraph from decisions 1 to 3.
3. Write `docs/phases/01-inventory.md` from the template (decision 4).
4. Trim the blueprint as decision 7 says, in its own `docs/` PR.

## Open decisions

<!-- Decisions only the owner can take, each a question with the options
and what each costs. When one is pending, the frontmatter says
`needs_owner: true` and names it in `needs_owner_why`. Answered ones stay,
with the date and the answer. -->

Answered 2026-10-20, with the owner, in this order:

1. **What CLM means.** Certificate lifecycle management: issue, renew,
   revoke and inventory X.509 certificates behind one interface.
   Rejected: contract lifecycle management (the vendor-neutral property
   and the security focus have little to hold on to there).
2. **The system's role.** A manager over existing CAs, not a CA of its
   own. The first CA is the owner's `LockedWayi/multivendor-hsm-pki`
   (`POST /certificates`, `POST /certificates/{serial}/revoke`, CRL,
   OCSP). Rejected: running our own CA (root-key custody, scope);
   inventory only (half a lifecycle). Its write endpoints need mutual
   TLS, whose bootstrap in that repository is built and **not yet run**;
   phase 03 depends on it.
3. **A second backend.** Not now; only the owner's CA at first.
   Rejected for now: ACME/Pebble, step-ca, Vault/OpenBao PKI. The cost:
   the interface is shaped by one implementation, and "vendor-neutral"
   is **not yet true** until phase 05 adds a second backend.
4. **The order of phases**, by value over effort:
   01 inventory and discovery (TLS endpoints, PEM files, a JSON
   inventory, `list --expiring`); 02 read-only web UI; 03 the CA
   interface and the adapter for the owner's CA (issue, revoke);
   04 automatic renewal; 05 a second backend (ACME/Pebble);
   06 write actions from the UI (needs login, authorisation, CSRF).
   Rejected: the CA integration first (waits on the mTLS bootstrap);
   the UI first (no data model to show yet).
5. **UI technology.** React with Vite, a single-page app over a JSON
   API from the Go service. Rejected: Go `html/template` with htmx
   (recommended; smaller supply chain, no second language). The cost,
   carried by phase 02: Node becomes a second language in `ci/lang/`,
   with its own pinned image, lint, test, coverage and npm dependency
   scan.
6. **GitHub.** Public now, `main` protected. Rejected: private first
   (no branch protection on a free private repository); no remote.
7. **Document load.** A light trim: the blueprint sections this
   repository dropped shrink to one-line notes; the threat model and
   the test matrix are updated when a phase closes rather than in every
   PR, recorded as a deviation. Rejected: no trim; a heavy trim (drops
   the discipline the portfolio shows).
