# ci/lang/

The language-specific half of each gate. `new-project.sh` fills this
directory from `template/go/ci/lang/` or `template/python/ci/lang/`. The
scripts one level up (`ci/*.sh`) hold the policy and are the same in every
project; the scripts here hold the measurement.

The contract a language provides:

| File | Called by | Must |
|---|---|---|
| `pins.sh` | `ci/pins.sh` (sourced) | pin the toolchain image by digest; set `SEMGREP_LANG_RULESETS`, `LANG_DEPS_SCANNER` and `TRIVY_FS_LANG_ARGS` (so trivy reads every lockfile); define `inToolchain` |
| `test.sh` | `ci/test.sh` | run every test in the pinned toolchain with result caches off, and exit non-zero when no test ran |
| `lint.sh` | `ci/lint-code.sh` | check formatting, vet or types, and lint; refuse when there is nothing to lint |
| `coverage.sh <exclude> <out>` | `ci/coverage.sh` | honour the exclusion file and write one percentage to `<out>` |
| `scan-deps.sh <report>` | `ci/scan-deps.sh` | write the scanner's report in a format `ci/vuln-gate.py filter` knows; the verdict is the gate's, not the scanner's exit status |

A new language is a new directory under `template/` with these five files
and a format added to `ci/vuln-gate.py`.
