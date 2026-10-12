# Contributing

This project follows [docs/BLUEPRINT.md](docs/BLUEPRINT.md). This file is
the working summary of it.

## Workflow

1. Create a branch off `main`: `feat/…`, `fix/…`, `docs/…`, `test/…`,
   `refactor/…`, `chore/…`, `ci/…`; `exp/…` for an experiment that may
   never merge.
2. Make one focused change. Keep PRs small; one piece of work may be
   several of them.
3. Write or update tests. For a fix, include the test that fails without
   it. The coverage floor is 70%.
4. Update the documents in the same PR as the behaviour: `CHANGELOG.md`,
   and `docs/threat-model.md`, `docs/test-matrix.md`, `README.md` status
   and `docs/architecture.md` where they are affected.
5. Run the gates locally before pushing. Every gate is a script, run the
   same way here and in the pipeline, so a red check is reproducible
   without pushing again:

   ```sh
   ci/lint-code.sh              # gofmt, go vet, golangci-lint
   ci/test.sh                   # go test -race
   ci/coverage.sh               # the 70% floor
   ci/scan-code.sh              # Semgrep (SAST)
   ci/scan-secrets.sh           # gitleaks over the full history
   ci/scan-deps.sh              # trivy fs + govulncheck, and unused allowlist entries
   ci/scan-iac.sh               # trivy config over Dockerfiles, manifests, IaC
   ci/lint-shell.sh             # shellcheck, warning and above
   ci/check-pins.sh             # every image by digest, every action by SHA
   ci/check-allowlist.sh        # every exception has a reason and an expiry
   tools/check-public-links.sh  # every relative link resolves
   ci/check-progress.sh         # PROGRESS and phase frontmatter within the contract
   ci/session-close-selftest.sh # the close gate refuses each of its reasons
   ```

   The host needs `docker`, `git` and `bash`; every tool runs from an
   image pinned in `ci/pins.sh` or `ci/lang/pins.sh`. The scanners fetch
   their databases, so they need network. These are the gates the
   pipeline runs. A check that cannot be run from here does not belong
   in the workflow.
6. End the session by closing it: `docs/PROGRESS.md` frontmatter written
   (`updated` today), `tools/next-session.sh` run, everything pushed, CI
   green, then `tools/session-close.sh` exits 0. `CLAUDE.md` "Resuming
   work" has the detail.
7. Open a PR. Fill in the template, including the **reasoning note** for
   any decision with a real alternative: what you decided, what you
   rejected and why, and what changes for an attacker.

## Commit messages

Conventional Commits with a scope: `feat(api): …`, `fix(ci): …`,
`docs(threat-model): …`. The subject states a fact about the system after
the change, lower case, present tense, no trailing period:

```
feat(api): the write endpoints are served over mutual TLS only
fix(ci): the dependency gate installed its scanner and never ran it
```

The body says why. It ends in trailers, one per line, as many as apply:

```
Decision: …
Alternatives: … (why it lost); … (why it lost)
Security: … | none, because …
Finding: …
Verified: <exact commands and their counts>
```

One logical change per commit. All code, comments and commit messages in
English.

## Accepting a finding

- **Semgrep:** a `nosemgrep: <rule-id>` comment on the exact line, with
  the reason beside it. Never a disabled ruleset, never a path exclusion.
- **Lint:** the linter's own line directive, naming the rule, with the
  reason. Never a disabled linter, never an excluded path.
- **Vulnerability (`trivy`, govulncheck):** an entry in
  `ci/vuln-allowlist.yaml` with `id`, a `statement` of why it does not
  apply *here*, and `expired_at` at most 180 days out.
  `ci/check-allowlist.sh` refuses anything less; `ci/scan-deps.sh` fails
  on an entry that suppresses nothing. Never edit a severity threshold.
- **gitleaks:** an exact-match regex in `.gitleaks.toml` for a recurring
  public string, or a commit-pinned fingerprint in `.gitleaksignore` for
  a one-off historical finding. Never a path.
- **shellcheck:** `# shellcheck disable=SCxxxx` on the line, with the
  reason.
- **Coverage:** `ci/coverage-exclude.txt` is for code CI cannot execute,
  never for code that is hard to test, and each entry says what verifies
  it instead.

## Protecting main

Every job in `.github/workflows/ci.yml` is a required check, and
`enforce_admins` is on, so the owner is not exempt. The contexts are the
jobs' `name:` values:

```sh
gh api -X PUT repos/<owner>/<repo>/branches/main/protection --input - <<'JSON'
{"required_status_checks":{"strict":false,"contexts":[
   "suite (lint, test, coverage)","SAST (Semgrep)","secret scan (full history)",
   "dependency scan","infrastructure scan"]},
 "enforce_admins":true,"required_pull_request_reviews":null,
 "restrictions":null,"allow_force_pushes":false,"allow_deletions":false}
JSON
```

Read it back afterwards and record the result in `docs/threat-model.md`
under the repository-writer attacker:
`gh api repos/<owner>/<repo>/branches/main/protection`.

## Working state

`.local/` holds caches, scan output and throwaway fixtures. It is
gitignored and excluded from the Docker build context. Delete it to start
clean; Go's module cache is read-only by design, so use
`chmod -R u+w .local && rm -rf .local`.

## Non-negotiables

- No secrets in commits or history. The secret scan is a required check,
  for the repository owner too.
- Secrets are referenced by environment-variable name, never by value, and
  never reach plaintext disk, an image or a log.
- Standard-library crypto unless a decision record says otherwise. No
  hand-rolled crypto. Secure randomness everywhere, identifiers included.
- Every ambiguous security decision fails closed.
- No claim in a document without a test, a script or a recorded run behind
  it; a claim that is not yet true is labelled as such.

The checks in `ci/` enforce the above. Run them before you push.
