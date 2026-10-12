# Project blueprint

How a project of mine is organised, documented and gated: rules, each
with its reason. The method is extracted from one reference repository,
without its code or subject matter. `template/` already satisfies every
rule, and `new-project.sh` makes a project from it.

## Contents

1. [The principles under every rule](#1-the-principles-under-every-rule)
2. [Repository layout](#2-repository-layout)
3. [The document set](#3-the-document-set)
4. [Writing style](#4-writing-style)
5. [Commit messages](#5-commit-messages)
6. [Git workflow](#6-git-workflow)
7. [CI philosophy](#7-ci-philosophy)
8. [The gates](#8-the-gates)
9. [Exceptions: allowlists and suppressions](#9-exceptions-allowlists-and-suppressions)
10. [Testing philosophy](#10-testing-philosophy)
11. [Security defaults](#11-security-defaults)
12. [Working in phases](#12-working-in-phases)
13. [Starting a project](#13-starting-a-project)
14. [Session hand-over](#14-session-hand-over)

## 1. The principles under every rule

- **A claim is not a measurement.** Every statement a document makes about
  the system is backed by a test, a script or a recorded run, or it is
  labelled as not yet true.
  *Reason: a document ahead of the code misleads silently until
  something depends on it.*
- **A check that is present is assumed to run. Prove that it runs.** A
  gate reports what it examined. It refuses to report clean over nothing.
  *Reason: in the reference repository a dependency gate installed its
  scanner, never ran it, and printed "clean" for five days.*
- **Fail closed.** Anything ambiguous, missing, half configured or
  unrecognised is a refusal with a reason. It is never a default.
  *Reason: a refusal costs a retry; a guess costs an incident.*
- **One place per decision.** One allowlist, one pins file, one registry
  of backends, one list of required gates.
  *Reason: two copies of a decision drift apart invisibly.*
- **Say what was not tested.** "Not measured" is a valid cell in a
  table. Silence is not.
  *Reason: a reader reads silence as coverage.*

## 2. Repository layout

| Directory | Holds | Does not hold |
|---|---|---|
| `cmd/<binary>/` | One directory per executable. It parses flags and config, wires dependencies and calls into the core. | Logic worth testing on its own. |
| `internal/` (Go) or `src/<package>/` (Python) | All product logic, one package per concern, with dependencies pointing inward toward the core. | Entry points, deployment files, scripts. |
| `ci/` | Every gate, and every script the pipeline runs. Also `ci/pins.sh`, `ci/vuln-allowlist.yaml`, `ci/coverage-exclude.txt`. | Anything a person runs by hand that is not also a gate. |
| `ci/lang/` | The language-specific half of each gate: how to test, lint, measure coverage and scan dependencies in this language. | Policy. Floors, allowlist rules and required gates stay in `ci/*.sh`. |
| `deploy/` | How the system runs somewhere: Dockerfiles, manifests, IaC, a `run-local.sh` that brings the whole thing up on one machine. | Product logic, and secrets of any kind. |
| `docs/` | The document set (§3), `docs/phases/`, and generated artifacts a document displays, such as a coverage badge. These are committed like lockfiles. | Working notes, drafts, vendor material. |
| `tools/` | Scripts a person runs on a workstation or a tree: bootstrap, measurement loops, the link checker, cleanup. A gate may call one. | Gates whose only caller is the pipeline. |
| `.local/` | Gitignored working state: caches, scan output, throwaway fixtures. | Anything that is committed, or anything a build context copies in. |

**The rule that decides where a new file goes.** Ask these in order and
stop at the first yes:

1. Does the pipeline run it to decide pass or fail? → `ci/`, and the
   language-specific half goes in `ci/lang/`.
2. Is it part of a program the project ships? Entry point → `cmd/`.
   Everything else → `internal/` or `src/`.
3. Does it describe how the system runs in an environment? → `deploy/`.
4. Is it prose a reader needs, or an artifact a document shows? → `docs/`.
5. Does a person run it against a workstation or a tree? → `tools/`.
6. Does a tool require it at the root, like `go.mod`, `pyproject.toml` or
   `.gitleaks.toml`? → the root.

Still no? It is a design question, not a filing question.
*Reason: a file with no home is a responsibility with no owner.*

- **Keep the core extractable.** No package in the core imports from
  `cmd/`, `deploy/` or a sibling concern that sits above it.
  *Reason: publishing the core as a library later is free only if the
  option was never lost.*
- **Nothing that can write at run time lives in the image.** The runtime
  has a small list of writable paths. A new one is a design decision and
  gets a decision record.
  *Reason: a read-only root is a control only while the writable list
  stays short and is written down.*
- **Material that is not the project's to publish (plans, vendor notes,
  anything under another licence) lives in a private repository, and
  nothing links into it.**
  *Reason: a link into it resolves privately and is dead in public;
  `tools/check-public-links.sh` catches it.*

## 3. The document set

Each document has one job. When a fact belongs to a document, it lives
there and the others link to it.

| Document | Its one job |
|---|---|
| `README.md` | What this is, why it is unusual, what is measured and what is claimed. |
| `docs/architecture.md` | Why it is built this way: the shape of the system and a decision record for every choice with a real alternative. |
| `docs/threat-model.md` | What it protects, from whom, what each attacker gets and does not get, and what recovery costs. |
| `docs/test-matrix.md` | What runs where, what each suite proves, and what a new backend or environment must provide. |
| `docs/runbook.md` (and ceremony documents) | What an operator does, step by step, and what to do when something is lost. |
| `CHANGELOG.md` | What changed, for a reader who was not there. |
| `CONTRIBUTING.md` | How to make a change that passes the gates, including how to accept a finding. |
| `SECURITY.md` | How to report a vulnerability privately, and what is in scope. |

### README.md

- **Open with "Why this is unusual".** One paragraph says what most
  projects in this space do and what this one does differently. A
  status table follows, and every row says how that row was verified.
  *Reason: a reader decides in the first screen whether the rest is
  worth reading.*
- **Keep two tiers of status.** *CI-verified* means an automated run on
  every push backs it. *Maintainer-verified* means it was run by hand in
  an environment CI does not have. Nothing maintainer-verified is
  reported as CI-verified.
  *Reason: that line is the difference between evidence and testimony,
  and the reader is owed it.*
- **Include the gate table.** One row per gate, with the columns
  `Check | Reads | Answers | Required` (§8). Say which gates are required
  on `main` and that `enforce_admins` is on.
  *Reason: it shows the pipeline's coverage in one place, and each
  gate's blind spot next to it.*
- **Link one demonstration of a gate blocking.** Keep one pull request
  that introduces a plausible mistake the tests miss, shows the gate turn
  red and the merge get refused, and then shows the fix.
  *Reason: "the gate blocks" is a claim. A red check on a real PR is a
  measurement.*
- **Say what is next, and what is designed but not scheduled.**
  *Reason: it stops a reader from mistaking a design for a feature.*
- **Include "Running it" and "Security posture".** The shortest path to
  a local run, and the non-negotiables stated as facts.
  *Reason: a reader who cannot run it in five minutes stops reading.*

### docs/architecture.md

- **Open with "What this is, in one paragraph" and "What this is not".**
  *Reason: scope stated up front prevents requests for features the
  design rules out.*
- **Explain the layering, and why it is ordered that way.** Each layer
  is proven before the next is added.
  *Reason: the security-critical surface is never large and untested at
  the same time.*
- **Write every key decision as a decision record.** Each record is a
  heading and three parts: **Rejected:** the alternatives, each with the
  real reason it lost. **Chosen:** what was done. **Reason:** why, and
  **the cost** of the choice, stated.
  *Reason: a decision recorded without its alternatives gets reopened by
  the next person, who does not know what was already tried.*
- **Record reversals and when they happened.** "X was the plan until
  YYYY-MM-DD and is now optional" stays in the record. It is not deleted.
  *Reason: the history of a decision is part of its justification.*
- **Record measured behaviour of external systems under "as measured".**
  Give the version, the date, the conditions and what was not measured.
  *Reason: behaviour you did not measure is a guess, and the next
  version may break it.*

### docs/threat-model.md

- **Put a dated status line first.** "**Status on YYYY-MM-DD.** The
  system has X, Y and Z. It has no A and no B." Update it in the same PR
  as any change it describes.
  *Reason: a threat model without a date cannot be checked against the
  code.*
- **Use this structure:** 1 How to read this · 2 Assets
  (`Asset | Where it lives | Loss means`, ordered by cost of loss) · 3
  Trust boundaries · 4 Attacker classes · 5 What each attacker gets, and
  does not · 6 Findings this model produced · 7 Non-goals · 8 What
  planned work changes · 9 Cross-references.
  *Reason: the same order in every project means a reviewer knows where
  to look.*
- **Give each attacker (A1…An) four parts: Gets, Does not get, Recovery
  and Limit.** "Gets" names a concrete capability, not a label. "Does not
  get" is the part that justifies the design. Recovery states its cost,
  because two compromises that differ only in recovery cost are
  different compromises.
  *Reason: a threat model that lists only what is defended is a brochure.*
- **Make every "cannot" traceable to a mechanism.** Name the function,
  the config field that does not exist, or the test that fails if the
  claim is broken (`TestConfig_NoRootReferences` style).
  *Reason: a boundary enforced by what a process cannot name survives
  code execution; one enforced by convention does not.*
- **Label claims that are not yet true** as **not yet true**,
  **planned** or **documented-design**.
  *Reason: the reader must be able to tell a design from a mechanism.*
- **Keep §6, the findings the model produced.** Writing the model is a
  review, and its findings are recorded with what was fixed and what
  residual was accepted, including the options that were rejected.
  *Reason: most real defects in the reference repository were found by
  writing this document.*
- **Include the repository itself as an attacker class** ("writer to
  this repository"), stated against branch protection as read from the
  API, including whether PR review is required.
  *Reason: the pipeline trusts the tree, so whoever writes the tree is in
  scope.*

### docs/test-matrix.md

- **Six sections, in this order:** why more than one backend (with the
  defect a single one hid) · the harness (how a test asks for a backend,
  the skip policy, run-scoped names) · what runs everywhere
  (`Suite | Tests | Proves`, a total, its date and the command that
  counted it) · what does not multiply · adding a backend (declared
  capabilities, expected divergences with measured values) · running it.
  *Reason: the cost of adding a backend stays "an adapter and a registry
  entry" only while the inventory is written down.*

### Runbook and ceremony documents

- **Open with "How to read this", mapping audiences to sections; give
  each procedure the same parts** (who, with what access, what to decide
  beforehand and which of it is irreversible, how to run it, what comes
  out and what does not); **order recovery by tier** (routine,
  exceptional, everything lost); label an unrun procedure
  **documented-design**.
  *Reason: the operator who opens it during an incident needs one
  section, and needs to know whether it has ever been run.*

### CHANGELOG.md

- **Follow [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/)
  and [SemVer 2.0.0](https://semver.org/spec/v2.0.0.html).** Use
  `## [Unreleased]` and `## [x.y.z], YYYY-MM-DD`, with `### Added`,
  `### Changed`, `### Fixed`, `### Security`, `### Removed` and
  `### Deprecated`.
- **Start each entry with a bold sentence that states a fact.** The body
  says what changed, what was measured and what was not.
  *Reason: the bold lines alone should read as a release summary.*
- **A `Fixed` entry about a false claim says what was claimed, since
  when, and what checks it now; every entry lands in the same PR as the
  behaviour.**
  *Reason: a changelog written at release time is written from memory.*

### CONTRIBUTING.md

- **It holds the workflow, the exact gate commands, how to accept a
  finding per scanner, the coverage floor, the commit convention and the
  non-negotiables**, and ends "The checks in `ci/` enforce the above."
  *Reason: a contributor needs one page that is enough to get to green.*

## 4. Writing style

This applies to documents, script headers, code comments and PR
descriptions.

- **Use the plain voice.** Short declarative sentences in the present
  tense. No marketing words, no "simply", no "robust", no "seamless".
  *Reason: rewriting the reference repository in this voice exposed false
  claims the ornate version had hidden.*
- **State the capability, not the label.** Write "can issue a
  certificate for any name until X", not "gets the key".
  *Reason: a label hides the blast radius the reader needs to judge.*
- **Give a number with its date, its conditions and its command.**
  Write "134 subtests, measured 2026-09-28 inside the container, with
  `<command>`".
  *Reason: a number without a date cannot be re-checked.*
- **Separate measured from inferred.** "Consistent with X and not proof
  of it" is a complete sentence.
  *Reason: an inference written as a result gets built on.*
- **Correct wrong claims visibly.** Strike the old claim through
  (`~~…~~`), then write "Measured YYYY-MM-DD:" and the new value. Do not
  quietly edit it.
  *Reason: a reader who acted on the old claim needs to see that it
  changed.*
- **Give every script a header that says why it exists.** The header
  gives the usage line, the question the script answers, the incident
  that caused it (with a date) when there was one, and any rejected
  alternative and why it lost.
  *Reason: a guard with no recorded reason is the first thing someone
  removes.*
- **Comments say why, not what; everything is in English.**
  *Reason: the code already says what, and one language keeps the
  history searchable.*

## 5. Commit messages

- **Use Conventional Commits with a scope:** `type(scope): subject`. The
  types are `feat`, `fix`, `docs`, `test`, `refactor`, `chore` and `ci`.
  The scope is a package, a directory or a document (`api`, `ci`,
  `deploy`, `tools`, `test-matrix`). `tools(<name>)` is allowed for a
  single-script change in `tools/`.
  *Reason: the type and scope let a reader filter the history.*
- **The subject states a fact about the system after the change.** Use
  lowercase after the colon, the present tense, no trailing period, and
  aim for 72 characters or fewer. It is not an instruction to the
  codebase ("add X") and not a ticket number.
  *Reason: `git log --oneline` then reads as a list of properties the
  system has.*
- **A `fix` subject names the defect as observed; one logical change
  per commit.** *Reason: a revert or a bisect lands on one fact.*

Five subjects from the reference repository's history:

```
feat(api): the write endpoints are served over mutual TLS only
fix(ci): the dependency gate installed govulncheck and never ran it
feat(ca): every certificate is issued under a named profile, and none under a default
fix(ci): a union missing a scanner is not a union
fix(deploy): pass the token PINs into the containers by name, not value
```

These are what the rule excludes, also from that history: `T2.1: seven
required checks, counted from the API` (a ticket prefix and no type) and
`docs: bring the documentation back in line with the code` (true, but it
says nothing about which claim changed).

- **The body explains why, then ends in trailers.** The body is plain
  prose: what was wrong or missing, what changed, and what was found on
  the way. Then add one trailer per line, as many as apply:

  ```
  Decision: <what was decided, one line>
  Alternatives: <each rejected option, with why it lost>
  Security: <what changes for an attacker, or "none" and why>
  Finding: <a measured fact learned while doing this>
  Verified: <the exact commands run and their counts>
  ```

  *Reason: the trailers make the reasoning note greppable. For example,
  `git log --format=%B | grep '^Decision:'` lists every decision the
  project made.*
- **Dependency bots use `chore(deps)` and `ci` prefixes**; their
  reasoning lives in the PR. *Reason: a bot cannot write the trailers.*

## 6. Git workflow

- **Branch off `main`** as `feat/…`, `fix/…`, `docs/…`, `test/…`,
  `refactor/…`, `chore/…` or `ci/…`. Use `exp/…` for an experiment that
  may never merge, `land/…` for a reviewed stack landing together and
  `release/vX.Y.Z` for a release cut.
  *Reason: the prefix matches the commit type, so the branch list and
  the history read the same way.*
- **Keep each PR small and focused.** One piece of work may be several
  PRs. A PR that touches the core and the docs of a different concern is
  two PRs.
  *Reason: a small PR can be read in full, and a PR that is not read
  was not reviewed.*
- **Every PR description has a reasoning note** (the template is
  `.github/pull_request_template.md`). The sections are **Why**, **What**,
  **Decision / Alternatives rejected**, **Security**, **Verified**
  (exact commands and results, including runs outside CI) and
  **Documents updated**.
  *Reason: a reviewer, or you in six months, should not have to rebuild
  the reasoning from the diff.*
- **Update the documents in the same PR as the behaviour.** That means
  the threat model, the test matrix, the README status and the
  CHANGELOG.
  *Reason: in the reference repository, "docs: sync with code" PRs kept
  appearing until this rule was followed.*
- **Protect `main`.** Make every blocking gate a required status check.
  Turn `enforce_admins` on, so the owner is not exempt. Refuse
  force-pushes and deletions.
  *Reason: a gate the owner can wave through is a report, not a gate.*
  The `gh api` call is in the template's CONTRIBUTING.md.

- **Merge with merge commits; squash nothing that carries a reasoning
  note.** *Reason: the trailers are the record.*

## 7. CI philosophy

- **Every gate is a script in `ci/`, and it runs the same way locally
  and in the pipeline.** A workflow `run:` step is one call to one
  script. A check that cannot be run locally does not belong in the
  workflow.
  *Reason: a red check you cannot reproduce without pushing again is a
  check people learn to retry instead of read.*
- **Each gate reads a different artifact.** The README's gate table
  says which. Two gates that read the same artifact are merged or
  justified.
  *Reason: a finding in one artifact is invisible to a scanner reading
  another, and that invisibility is the reason to have several gates.*
- **Every tool runs from a pinned container, not from the host's PATH.**
  Images are pinned by digest in `ci/pins.sh`, with the tag in a comment
  beside each one. Tools installed from a checksummed module proxy (Go
  modules) or a hash-locked index (pip) are pinned by exact version.
  Workflow actions are pinned by commit SHA.
  *Reason: a tag is a pointer its publisher can move, so a tag-pinned
  image is chosen by someone else after your review.*
- **`ci/check-pins.sh` checks the pin claim.**
  *Reason: in the reference repository it was false in six places
  before a script checked it.*
- **The exit status is not evidence that a scan happened.** A gate
  checks for evidence of work: a count of files or manifests read, a
  completion marker, a hits file from every scanner expected to report.
  *Reason: "clean" and "never ran" both exit 0. Building this blueprint
  found one: `trivy fs` recognises only a file named `requirements.txt`,
  and reported a Python project clean over a tool lock it never read.*
- **Keep exceptions in one reviewed place per kind** (§9); never lower a
  threshold, disable a ruleset or exclude a path to get to green.
  *Reason: each of those silences every future finding, not this one.*
- **Keep automated dependency updates.** Dependabot covers go.mod or
  pip, the actions and Dockerfiles. Pins it cannot see, such as digests
  in `ci/pins.sh`, get a scheduled freshness check in a separate
  workflow that is not required.
  *Reason: a scanner without an update mechanism is a red pipeline that
  stays red; upstream shipping a release must not block a PR.*
- **Least privilege in the workflow:** top-level
  `permissions: contents: read`, widened per job only where needed.
  *Reason: a compromised step can do only what its token allows.*
- **Put a job downstream of the gates when it publishes, and have it
  re-assert every gate's result at run time.** A hard-coded list of
  required gates in that check refuses an unknown or missing gate.
  *Reason: `needs:` and `if:` interact in ways that are easy to misread.
  A gate that was deleted must fail something.*
- **A rule adopted late arrives with its backlog handled.** The PR that
  adds a check records what its first run found (`Finding:`) and fixes
  or allowlists each finding.
  *Reason: a check that starts with silent exceptions starts as a
  report, not a gate.*
- **Make every guard prove its refusals.** A script that refuses things
  gets a `*-selftest.sh` that drives each refusal and each acceptance,
  and the selftest runs in a required job.
  *Reason: a guard nobody has seen refuse is decoration.*

## 8. The gates

These are what `template/` ships. Each one exits 0 on a freshly
generated project and fails on a finding.

| Script | Reads | Answers | Required |
|---|---|---|---|
| `ci/test.sh` | the code, run | does it work? (`go test -race`, or pytest); refuses a run with no tests | yes |
| `ci/coverage.sh` | the code, run | is enough of it exercised? (floor: 70%) | yes |
| `ci/lint-code.sh` | the code, read | formatting, vet or type errors, lint | yes |
| `ci/scan-code.sh` | the code you wrote | did we write a known-dangerous pattern? (Semgrep) | yes |
| `ci/scan-secrets.sh` | every commit in history | did we commit a secret, ever? (gitleaks, full history, refuses a shallow clone) | yes |
| `ci/scan-deps.sh` | what you imported | is a vulnerable version present (trivy fs), and is it reached or installed (govulncheck or pip-audit)? It also checks every allowlist entry suppressed something. | yes |
| `ci/scan-iac.sh` | what would be provisioned | is the Dockerfile, manifest or IaC misconfigured? (trivy config) | yes |
| `ci/lint-shell.sh` | every tracked `*.sh` | shellcheck, warning and above | yes |
| `ci/check-pins.sh` | Dockerfiles, scripts, workflows | is every image pinned by digest and every action by SHA? | yes |
| `ci/check-allowlist.sh` | `ci/vuln-allowlist.yaml` | does every exception have an id, a reason and an expiry at most 180 days out? | yes |
| `tools/check-public-links.sh` | every tracked `*.md` | does every relative link resolve? | yes |

Add these when the project reaches the stage that needs them, in the
same PR as the first artifact they read:

| Script | Add it with | Reads |
|---|---|---|
| `ci/scan-image.sh` | the first Dockerfile that ships | the assembled image: trivy image plus an SBOM |
| `ci/verify-*.sh` | the first signed artifact | signatures, checked from a checkout that holds no key |
| `ci/assert-publishable.sh` plus selftest | the first publish job | every gate's result in this run |

When a second job consumes the allowlist (`scan-image`), the "every
entry was used" check moves to its own job downstream of both, judging
the union of their hits files.
*Reason: an entry covering a finding only trivy image sees matches
nothing in the dependency scan and is still correct.*

## 9. Exceptions: allowlists and suppressions

- **Keep one vulnerability allowlist, `ci/vuln-allowlist.yaml`, in
  trivy's schema.** Every entry has `id`, `statement` (why it does not
  apply *here*: the path is unreachable, the feature is not built, the
  fix is not released) and `expired_at` at most 180 days out.
  `ci/check-allowlist.sh` refuses an entry that is missing any of them,
  or that has already expired.
  *Reason: trivy honours an entry with no expiry forever. An exception
  nobody has to renew is a forgotten risk, not an accepted one.*
- **An entry that suppressed nothing fails the build.** Each scanner
  writes which entries it used, and the union is judged.
  *Reason: an exception that has stopped matching looks, from outside,
  exactly like a clean scan.*
- **Accept a Semgrep finding with `nosemgrep: <rule-id>` on the exact
  line and the reason beside it.** Never disable a ruleset and never
  exclude a path.
  *Reason: a path exclusion exempts every future finding in that file
  too.*
- **Accept a gitleaks finding in one of two ways.** A recurring public
  string gets an exact-match regex in `.gitleaks.toml`. A one-off
  historical finding gets a commit-pinned fingerprint in
  `.gitleaksignore`. Never allowlist a source path.
  *Reason: a fingerprint re-triggers when the content moves. A path
  exemption grows silently.*
- **Accept a shellcheck or lint finding with the tool's directive on the
  line, naming the rule, with the reason.** *Reason: as for Semgrep.*
- **The coverage exclusion file lists code CI cannot run, never code
  that is hard to test.** Each entry in `ci/coverage-exclude.txt` says
  what verifies that code instead, and the claim is labelled
  maintainer-verified wherever it is made.
  *Reason: a floor that gets lowered until it passes protects nothing.
  A floor over code CI cannot execute blocks every merge.*

## 10. Testing philosophy

- **Write one conformance suite and run it per backend.** Any test that
  touches an external implementation (a module, a database engine, a
  cloud API, an appliance) runs as its own subtest against every backend
  the environment provides, through one registry. Adding a backend means
  writing an adapter and adding one registry entry. No test is edited to
  add a backend.
  *Reason: an abstraction exercised against one implementation is a
  guess, and its shape silently encodes that implementation.*
- **Skip when a backend is absent. Fail when it is half configured.** No
  variables set means the backend skips, with a message. Some set and
  some missing means the test fails and names what is missing.
  *Reason: a half-configured backend is a mistake, and a skip would
  report it as a choice.*
- **A skip is not a pass.** Report counts as pass/skip/fail per backend.
  *Reason: "green" over skips means "not run" to everyone but the author.*
- **Turn every measured divergence into a declaration the suite
  asserts.** When two backends differ, the difference becomes a field
  the adapter declares, with no branch on the backend's name. The suite
  measures the declaration in both directions: a backend that declares a
  refusal and then complies fails, and one that declares compliance and
  then refuses fails.
  *Reason: a plain skip cannot notice the divergence going away. A
  vendor-name branch teaches the core a vendor.*
- **Read properties back from the system, not from your request.**
  *Reason: in the reference repository one conformant backend ignored a
  protection attribute another honoured, under a green suite.*
- **Measurements disable result caches.** Use `go test -count=1`, and do
  not reuse pytest's cache as evidence.
  *Reason: a replayed result never touched the backend.*
- **Keep the coverage floor at 70%**, the number `ci/coverage.sh`
  computes over code CI can run. A README badge is committed like a
  lockfile and CI recomputes it.
  *Reason: one number, one script; the workflow never needs write access.*
- **For every fix, a test that fails without it**, recorded in
  `Verified:` ("fails with the check removed").
  *Reason: a test that passes either way tests nothing.*
- **Test at the boundary a user crosses:** a CLI through its own entry
  point, a server through a real listener.
  *Reason: the wiring between the parts is where the last bug hides.*
- **Report hang or flake rates as rates**, counted over N runs by a
  script in `tools/`. *Reason: one clean run says nothing about a rate.*

## 11. Security defaults

- **Fail closed, and enforce on the server side.** Treat every
  client-side component as untrusted.
  *Reason: any client can be decompiled.*
- **Reference secrets by environment-variable name, never by value.**
  Configuration carries `pin_env: APP_DB_PASSWORD`, not the password.
  Code reads the value at the point of use and does not keep it longer
  than needed.
  *Reason: a secret in a config file ends up in a backup, a ticket or an
  image layer.*
- **Keep secrets out of images, out of the build context and out of
  logs at every level.** `.dockerignore` excludes `.local/`. Pass
  containers secrets by name (`docker run -e NAME`), never by value on a
  command line.
  *Reason: a command line is readable by every process on the host.*
- **Use standard-library cryptography unless a decision record says
  otherwise.** No hand-rolled crypto, and no convenience crypto
  libraries. `crypto/rand` or `secrets`, never `math/rand` or `random`,
  anywhere, including for identifiers.
  *Reason: an unaudited crypto helper undercuts the project, and weak
  randomness is exactly what tests cannot see.*
- **Identify things by immutable identity, never by display name:** a
  digest over a tag, a serial over a label. A lookup that matches more
  than one thing fails.
  *Reason: names are descriptions, and descriptions are allowed to
  collide.*
- **Separate keys and credentials by purpose**, with versioned names
  (`<purpose>-key-v1`) and a stated lifecycle (active, verify-only,
  retired).
  *Reason: a key with one purpose has one blast radius, and a key with a
  version can be rotated without a code change.*
- **Verify with an implementation that did not produce the artifact.**
  *Reason: a bug shared by signer and verifier verifies.*
- **Run as non-root with a read-only root filesystem**, and a written
  list of writable paths. *Reason: see §2; the list is the control.*
- **Keep the root of trust outside the tree it authenticates.** If
  verification needs an anchor, the anchor lives in another repository
  and the verifier supplies it.
  *Reason: three files that agree in one repository prove nothing.*

## 12. Working in phases

- **Split the work into phases under `docs/phases/`**, as
  `NN-short-name.md` from `PHASE-TEMPLATE.md`. Each phase states its
  goal, scope, out of scope, deliverables, "done when" criteria and the
  threat-model sections it must update.
  *Reason: a phase with a written "out of scope" does not grow.*
- **Every "done when" criterion is checkable by a test or a script,**
  written as the command that proves it. A criterion that needs
  judgment is split until it does not.
  *Reason: "done" is a claim, so it needs a measurement like any other.*
- **Split criteria into CI-verified and maintainer-verified**, as the
  README does. *Reason: the same line between evidence and testimony.*
- **A phase closes in a PR that updates its status line, the README
  status, the threat model's status line and the CHANGELOG; the next
  phase starts only on a green one.**
  *Reason: a layer is proven before the next is built on it.*
- **Every phase file opens with a frontmatter: `id`, `name`, `status`,
  `done_on`, `depends_on`.** The `**Status on YYYY-MM-DD:**` line in
  the body stays. The frontmatter is what machines read, the line is
  what a reader sees, and `ci/check-progress.sh` refuses a disagreement
  between them.
  *Reason: a dashboard that parses prose guesses; a line that only a
  machine reads goes stale. Two copies, one check.*
- **`depends_on` is explicit and required, never inferred from the
  number.** `[]` for a phase that depends on nothing. Numbering says the
  order the phases were planned in; `depends_on` says what must be green
  first, and the two differ as soon as a phase forks (`03a`, `03b`).
  *Reason: a dependency a reader infers from "03 comes after 02" is
  wrong the first time a phase is split, and nothing notices.*
- **Where the work stopped lives in exactly one place: `docs/PROGRESS.md`.**
  Its frontmatter is the contract (`project`, `status`, `phase`,
  `phase_status`, `next`, `blocked_on`, `needs_owner`,
  `needs_owner_why`, `updated`); its body keeps whatever form the
  project reads best. `ci/check-progress.sh` refuses a missing field, a
  value outside its vocabulary, or a `phase` with no file.
  *Reason: "where did we stop" answered from memory, a chat transcript
  or three documents is answered differently each time. One file with a
  fixed head can be read by a person and a program alike.*
- **A decision only the owner can take is a flag, not a paragraph.**
  `needs_owner: true` with the question in `needs_owner_why`, the
  choices as `needs_owner_options` (a list, one line each, `A) …`,
  `B) …`, the recommended one ending `(recommended: <why>)`), and the
  reasoning under "Open decisions" in the body. The owner answers with
  a letter. `ci/check-progress.sh` refuses `needs_owner: true` without
  a `needs_owner_why`, and warns when the options are empty.
  *Reason: a decision buried in prose waits until someone rereads the
  prose; a flag can be listed, sorted and sent, and a lettered list can
  be answered from a phone.*

- **A done phase is audited by a session that did not close it, and
  the audit is a file.** `docs/audits/NN-<name>.md`, written by the
  auditor on a clean checkout of `main` after running every "done when"
  again, with a frontmatter (`phase`, `head`, `verdict`, `date`) and
  committed on an `audit/NN` branch the owner merges. A failed audit
  puts the phase back to "in progress" in the same commit.
  `docs/audits/README.md` names in `audited_from` the first phase id
  the rule covers; from there `ci/check-progress.sh` refuses a done
  phase without a passing audit file, and without the README it warns.
  *Reason: "done" said by the session that did the work is the claim
  under review; the audit is the measurement, and a measurement nobody
  can find is a claim again. The opt-in exists because every repository
  has phases closed before an auditor existed.*

`template/CLAUDE.md` gives Claude Code the same rules; §14 says how a
session ends.

## 13. Starting a project

```sh
./new-project.sh --lang go     --name my-service --module github.com/me/my-service
./new-project.sh --lang python --name my-tool
```

It copies `template/` plus the language variant, copies this file to
`docs/BLUEPRINT.md`, substitutes the name, renders `docs/next-session.md`
from `docs/PROGRESS.md`, runs `git init -b main` and makes the first
commit. Then: run every gate (all exit 0 on the new project), create the
repository, protect `main` with the job names from `ci.yml` (§6), and
write `docs/architecture.md`'s one paragraph and `docs/phases/01-*.md`
before the first line of product code; `docs/PROGRESS.md` then names
`phase: "01"`, and from there every session ends as §14 says.

## 14. Session hand-over

A session of work, by a person or by Claude Code, ends with a hand-over,
not with a context to resume.

- **Hand over, do not resume.** Every session ends by writing
  `docs/next-session.md`, a paste-ready prompt built from PROGRESS's
  `next`, `blocked_on`, the open decisions and the three files to read
  first. `tools/next-session.sh` renders it. A new session starts clean
  from that prompt.
  *Reason: `claude --continue` reloads the whole old context, and a
  context that has been compacted once has already lost what it was
  compacted over. A prompt holds what the next session needs; a
  transcript holds what the last one did.*
- **Bound a session from inside the prompt, not by watching the
  context.** `docs/next-session.md` ends with "stop and close when the
  current deliverable lands or after about N tool calls", so a session
  hands over early rather than compacting.
  *Reason: the moment a context compacts is the moment the session
  forgets which rule it was following.*
- **Session close is a gate, not a reminder.** `tools/session-close.sh`
  exits 1 unless: PROGRESS's frontmatter was written today; nothing is
  unpushed and the tree is clean, or the dirty paths are the refusal;
  every CI run for HEAD is green, and no run yet counts as red; every
  phase file's frontmatter agrees with its status line;
  `docs/next-session.md` exists and is fresh; a pending owner decision
  has its question; and every repository hook in
  `tools/session-close.d/` passes. It writes `.local/state.json` with
  the frontmatter, each gate's result, HEAD, the branch and timestamps,
  which is what a dashboard reads first.
  *Reason: a reminder is followed when remembered. A session that ends
  with an unpushed commit, a red CI or a phase file that lies has left
  the next session a puzzle, and the next session is the one that pays.*
- **The gate runs as a Claude Code Stop hook** (`.claude/settings.json`).
  The hook invokes the script; the script decides: a red close blocks
  the stop with the reasons, at most three times in one session, and a
  turn that used no tool is never blocked.
  *Reason: a gate the agent has to remember to run is a reminder again.
  Three blocks bound the loop; a question answered is not a session to
  close.*
- **The permission allowlist in `.claude/settings.json` is exactly what
  git, gh and the gates need, and nothing wider.** `Bash(git <verb> *)`
  for the verbs a session uses, `Bash(gh pr *)`, `Bash(gh run *)`,
  `Bash(ci/*)`, `Bash(tools/*)`, `Edit` and `Write`. A headless session
  runs with `--permission-mode dontAsk`, so a command outside the list
  is denied and named, never approved by nobody; the watch refuses to
  continue on a denial. Widening the list is a reviewed change to this
  file, with the command and why.
  *Reason: `--dangerously-skip-permissions` is the alternative, and it
  turns a session that could run `git push` into one that can run
  anything. A denial costs one session; the list grows only by review.*
- **Project-specific close checks are hooks, not forks.** What a
  project must check before a session is over (a calendar, a register,
  an open position) goes in `tools/session-close.d/NN-*.sh`, run in
  order, each able to fail the close. The generic script is never
  edited per project.
  *Reason: a forked script stops receiving fixes; a hook keeps the
  generic part generic.*
- **The guard proves its refusals.** `ci/session-close-selftest.sh`
  builds a throwaway repository, shows the gate exit 0, then breaks one
  thing at a time and shows it exit 1 with that reason, and that reason
  only. It runs in the required `suite` job (§7).
  *Reason: as for every guard. A close gate nobody has seen refuse is a
  reminder with a shell script attached.*
