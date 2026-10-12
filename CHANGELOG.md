# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!-- Each entry opens with a bold sentence that states a fact about the
system; the body says what was measured and what was not. A Fixed entry
about a false claim says what was claimed, since when, and what checks it
now. Entries are added in the same PR as the behaviour. Sections, in this
order when present: Added, Changed, Deprecated, Removed, Fixed, Security. -->

## [Unreleased]

### Added
- **The project starts from project-blueprint with every gate green.**
  Lint, tests, the 70% coverage floor, Semgrep, gitleaks over the full
  history, `trivy fs` with govulncheck, `trivy config`, shellcheck,
  the pin check, the allowlist check and the link check, each a script in
  `ci/` or `tools/`, run the same way locally and in
  `.github/workflows/ci.yml`. Measured 2026-10-12 on the first commit.
