# Session-close hooks

Every executable `*.sh` here runs at the end of `tools/session-close.sh`,
in name order, after the generic gates. Each one may fail the close: a
non-zero exit is a refusal and its output is the reason. The generic
script knows nothing about the project; what a project must check before
a session is over goes here.

Name them `NN-<what>.sh`, give each the header every script has (why it
exists, what it refuses), and keep each to one question. A hook runs with
the repository root as its working directory and no arguments. It must
not change the tree: the close is a measurement, not a fix.

An example from one project: a research line keeps a catalyst calendar,
a red-flag coverage table and an open position; its hook calls the
project's own checker with a `--project-only` flag, so the generic gates
(CI, unpushed commits, phase status) are not done twice.

A directory with no hooks is fine. A hook that is not executable is a
refusal, not a skip: a check that is present is assumed to run.
