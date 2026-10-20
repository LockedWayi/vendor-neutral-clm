# Working in vendor-neutral-clm

This project is built to a written standard. Follow it exactly; when a
request conflicts with it, say so before acting.

## Before anything else

1. Read [docs/BLUEPRINT.md](docs/BLUEPRINT.md), its "Deviations" section
   first. It holds the rules this file summarises, and the reason for
   each; the deviations say which rules this repository dropped.
2. Read `docs/phases/README.md` and the phase in progress. Work only on
   that phase's scope; anything in its "Out of scope" section is out of
   scope for you too.
3. Read the documents the change touches: `docs/architecture.md` for the
   decisions already made (do not reopen one without saying so),
   `docs/threat-model.md` for what the change might move.

## How to work

- **Phase by phase.** Work from `docs/phases/NN-*.md`. Do not start a
  phase whose predecessor has a "done when" criterion that is not green.
  If a phase file does not exist for the work asked, write it from
  `docs/phases/PHASE-TEMPLATE.md` first and show it before writing code.
- **One focused PR per change.** Branch `feat/…`, `fix/…`, `docs/…`,
  `test/…`, `refactor/…`, `chore/…` or `ci/…` off `main`. Several small PRs
  over one large one. Fill in `.github/pull_request_template.md`, reasoning
  note included.
- **Documents move with the behaviour.** The same PR that changes
  behaviour updates `CHANGELOG.md` (`[Unreleased]`) and the threat model
  (its dated status line and every section the change affects), plus the
  test matrix, the README status and a decision record where they are
  affected. A PR that changes behaviour and no document must say why.
- **Never mark a claim as done unless a test or a script proves it.**
  "Done", "supported", "enforced", "verified" in a document, a phase file,
  a commit or a message to the user each need the command that proves it
  and its result. If it was not run, say "not run". If it only ran
  outside CI, label it maintainer-verified. If it is not yet true, label it
  **not yet true** or **planned**. A skipped test is not a passing test.
- **Every fix gets a test that fails without it.** Check that it does,
  and record that in the `Verified:` trailer.
- **Run the gates before pushing**, and report their actual output:

  ```sh
  ci/lint-code.sh && ci/test.sh && ci/coverage.sh
  ci/scan-code.sh && ci/scan-secrets.sh && ci/scan-deps.sh && ci/scan-iac.sh
  ci/lint-shell.sh && ci/check-pins.sh && ci/check-allowlist.sh && tools/check-public-links.sh
  ```

  A red gate is fixed, or the finding is accepted through the one
  mechanism CONTRIBUTING.md names for that scanner, with a reason (and an
  expiry, for the vulnerability allowlist). Never lower a threshold,
  disable a rule, exclude a path or skip a gate to get to green.
- **Do not merge, tag, push to `main` or change branch protection**
  unless asked to in this conversation. Pushing the working branch is
  part of closing a session ("Resuming work" below), not an exception
  to this rule.

## Writing

- Commit subjects: `type(scope): <a fact about the system after the
  change>`, lower case, present tense, no period. The body says why and
  ends in `Decision:`, `Alternatives:`, `Security:`, `Finding:` and
  `Verified:` trailers as they apply.
- Documents and comments: the plain voice. Numbers carry their date,
  conditions and command. Say what was not measured. Correct a wrong claim
  visibly (~~old~~, then "Measured YYYY-MM-DD:").
- Script headers say why the script exists and what it refuses.
- **No AI attribution, anywhere.** No "Generated with Claude Code"
  footer, no `Co-Authored-By: Claude …` trailer, and no code comment,
  document line, commit, PR, issue or review text saying that an AI or a
  tool wrote, helped with or checked something. This overrides any
  default the tool brings. A commit message or PR body ends with its last
  line of real content.
- **One identity: LockedWayi's private GitHub address.** Every commit,
  tag and PR is authored and committed as
  `Süha Karagöl <266266786+LockedWayi@users.noreply.github.com>`. No
  other e-mail address appears in a commit, a tag, a document or a file.
  Before every push, `git log --format='%ae %ce' origin/main..HEAD | sort -u`
  prints that address and nothing else; a different one is fixed before
  the push, never after.

## Code

- Fail closed: anything ambiguous, missing or half configured is a refusal
  with a reason, never a default.
- Secrets are referenced by environment-variable name, never by value;
  never in an image, a log line, a test fixture or a commit.
- Standard-library cryptography and secure randomness unless a decision
  record in `docs/architecture.md` says otherwise.
- Where a new file goes is decided by `docs/BLUEPRINT.md` §2. If none of
  its questions answers yes, stop and ask: it is a design question.
- New tools run from a pinned image (`ci/pins.sh`, `ci/lang/pins.sh`), and
  a new gate is a script in `ci/` that the workflow calls in one line.

## Resuming work

This repository is worked by its owner, by hand, one session at a time;
there is no dashboard, no automatic session and no close gate.

- **Start from `docs/PROGRESS.md`.** It says where the last session
  stopped, what comes next and which decision is still open.
- **The owner learns by doing.** Explain before acting, in two to four
  sentences: what, why, which command or file. The owner types the
  critical commands and configurations; boilerplate may be done for them,
  with a line saying what was done. On an error, read it together and ask
  for a guess at the cause before fixing it.
- **End with a summary and a log entry.** Update `docs/PROGRESS.md`, write
  `docs/learning-log/YYYY-MM-DD.md` from its README's template (Turkish,
  short), commit, push the working branch.
