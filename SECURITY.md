# Security policy

## Reporting a vulnerability

Report it privately through GitHub's **Report a vulnerability** button on
this repository's Security tab (private vulnerability reporting). Do not
open a public issue or pull request for it.

Include what an attacker gains, the conditions it needs, and a
reproduction if you have one. You will get an acknowledgement, and then
either a fix or a written reason why it is not one, which is added to
[docs/threat-model.md](docs/threat-model.md) as a finding or a non-goal.

## Scope

In scope: the code in this repository, its pipeline (`ci/`,
`.github/workflows/`) and the artifacts that pipeline publishes.

Out of scope: the non-goals listed in
[docs/threat-model.md](docs/threat-model.md) §7, and findings in
third-party dependencies that do not reach this project's code (report
those upstream; the dependency gate tracks them here).

## Supported versions

Only the latest release, and `main`, receive fixes until the project
states otherwise here.
