# vendor-neutral-clm

<!-- One or two sentences: what this is, and the property that matters
most, stated as a fact the code enforces. The design reasoning is in
docs/architecture.md. -->

vendor-neutral-clm is … The design reasoning is in
**[docs/architecture.md](docs/architecture.md)**.

## Why this is unusual

<!-- One paragraph: what most projects in this space do, and what this one
does differently. Then a status table where every row says how it was
verified. Delete this comment when the first row is true. -->

Most … hard-code … This one …

| Component or backend | Status |
|---|---|
| … | **Not yet built.** Planned in `docs/phases/01-….md`. |

<!-- Then a short list of the properties that make it unusual, each
traceable to a mechanism, e.g.:
- **One interface, one shared core.** …
- **One conformance suite, run per backend.** A backend the environment
  lacks skips; a backend half configured fails rather than skipping. -->

## The pipeline

Each check reads a different artifact, and a finding from one is
invisible to the others:

| Check | Reads | Answers | Required |
|---|---|---|---|
| lint + tests + coverage floor (`ci/lint-code.sh`, `ci/test.sh`, `ci/coverage.sh`) | the code, read and run | does it work (go test -race), and is 70% of it exercised? (gofmt, go vet, golangci-lint) | yes |
| Semgrep (`ci/scan-code.sh`) | the code you wrote | did we introduce a known-dangerous pattern? | yes |
| gitleaks (`ci/scan-secrets.sh`) | every commit in history | did we commit a secret, ever? | yes |
| `trivy fs` + govulncheck (`ci/scan-deps.sh`) | what you imported | is a vulnerable version present, and does this code reach it? | yes |
| `trivy config` (`ci/scan-iac.sh`) | what would be provisioned | is the infrastructure misconfigured? | yes |
| shellcheck, pins, allowlist, links (`ci/lint-shell.sh`, `ci/check-pins.sh`, `ci/check-allowlist.sh`, `tools/check-public-links.sh`) | the gates themselves and the documents | is every script sound, every image and action pinned, every exception dated and reasoned, every link alive? | yes |
| progress contract (`ci/check-progress.sh`) | `docs/PROGRESS.md` and `docs/phases/*.md` frontmatter | does every phase say what it depends on, and does each status agree with what a reader sees? | yes |
| session-close selftest (`ci/session-close-selftest.sh`) | `tools/session-close.sh`, driven in a throwaway repository | does the close gate refuse each of its seven reasons and accept a clean close? | yes |

Every check is a script in `ci/`, run the same way locally and in the
pipeline. All of them are **required** on `main`, the repository owner
included: `enforce_admins` is on. <!-- State whether PR review is
required, and point at the threat model's repository-writer attacker. -->

Accepted findings live in **one** reviewed allowlist,
`ci/vuln-allowlist.yaml`, and each entry carries a written reason and an
expiry date. An entry that suppresses nothing fails the build.

<!-- Link one PR that shows a gate blocking a plausible mistake the tests
did not catch, once there is one. -->

## Status

- **CI-verified.** <!-- What an automated run backs, on every push. -->
  The gates above, over a skeleton with one package and its tests.
- **Maintainer-verified.** <!-- What was run by hand, where, and which
  version. Nothing here is reported as CI-verified. --> Nothing yet.

Built and running: nothing beyond the skeleton. Planned next: see
[docs/phases/](docs/phases/README.md). <!-- Also say what is designed and
optional, not scheduled. -->

## Running it

```sh
ci/lint-code.sh      # gofmt, go vet, golangci-lint
ci/test.sh           # go test -race
ci/coverage.sh       # the 70% floor
```

Everything runs in pinned containers; the host needs `docker`, `git` and
`bash`. [CONTRIBUTING.md](CONTRIBUTING.md) has the rest.

## Security posture

- No secrets in the repository or its history. `gitleaks` scans every
  commit on every push.
- Secrets are referenced by environment-variable name, never by value,
  and never baked into an image or written to a log.
- Cryptographic primitives come from the standard library unless a
  decision record in [docs/architecture.md](docs/architecture.md) says
  otherwise.
- Every ambiguous security decision fails closed. All enforcement is
  server-side.

What this protects and from whom: [docs/threat-model.md](docs/threat-model.md).
How to report a vulnerability: [SECURITY.md](SECURITY.md).

## License

Apache-2.0. See [LICENSE](LICENSE).
