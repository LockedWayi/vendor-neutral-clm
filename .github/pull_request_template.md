<!--
Title: a Conventional Commit subject that states a fact about the system
after this change, e.g. "feat(api): the write endpoints are served over
mutual TLS only". One focused change per PR.
-->

## Why

<!-- What was wrong or missing, with the evidence: a measured number, a
failing command, a finding. Say what was *not* measured. -->

## What

<!-- The change, as a list. Name files and functions. Say what did not
change if a reader would expect it to. -->

-

## Reasoning note

<!-- Required for any decision with a real alternative. Copy these lines
into the commit body as trailers too. -->

**Decision:**
**Alternatives rejected:**
- <option>: <why it lost>

**Security:** <!-- What changes for an attacker, by attacker class in
docs/threat-model.md; or "none", and why. -->

**Finding:** <!-- A fact learned on the way, measured. Delete if none. -->

## Verified

<!-- The exact commands and their results. Include runs CI cannot make
(maintainer-verified) and label them as such. For a fix, the test that
fails with the fix removed. -->

```
ci/lint-code.sh && ci/test.sh && ci/coverage.sh
ci/scan-code.sh && ci/scan-secrets.sh && ci/scan-deps.sh && ci/scan-iac.sh
ci/lint-shell.sh && ci/check-pins.sh && ci/check-allowlist.sh && tools/check-public-links.sh
```

## Documents updated in this PR

- [ ] `CHANGELOG.md` (`[Unreleased]`)
- [ ] `docs/threat-model.md`: status line and affected sections, or not affected because …
- [ ] `docs/test-matrix.md`: counts and what runs where, or not affected because …
- [ ] `README.md` status, or not affected because …
- [ ] `docs/architecture.md` decision record, if a decision was made
- [ ] `docs/phases/NN-*.md` status line and frontmatter, if this closes a "done when" criterion
- [ ] `docs/PROGRESS.md` frontmatter and "Now", if this moves a deliverable
