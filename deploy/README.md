# deploy/

How this project runs somewhere: Dockerfiles, manifests, infrastructure
as code, and `run-local.sh`, which brings the whole system up on one
machine. See [BLUEPRINT.md §2](../docs/BLUEPRINT.md#2-repository-layout).

Empty until the first phase that ships a runnable artifact. Add
`ci/scan-image.sh` in the same PR as the first Dockerfile that ships
([BLUEPRINT.md §8](../docs/BLUEPRINT.md#8-the-gates)).

Rules that apply here:

- Every `FROM` is pinned by digest (`ci/check-pins.sh`).
- The runtime is non-root with a read-only root filesystem. Its writable
  paths are listed here, and a new one needs a decision record in
  `docs/architecture.md`.
- Secrets are passed by environment-variable name, never by value, and
  never baked into an image.
