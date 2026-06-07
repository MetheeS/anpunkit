# tests/regression/ — cross-phase contract corpus

Public-contract / ENDPOINTS-surface tests live here. This is the regression
guard: every phase CLOSE runs the mock corpus (`scripts/regression.sh`); the
final phase and `/replan` also run the real corpus (`--real`).

Rules:
- A regression test must NOT depend on phase-local fixtures.
- mock vs real is a fixture/env flag (`TEST_MODE`) on the SAME test — never
  duplicated files.
- Every `docs/ENDPOINTS.md` entry must have >=1 test here, or phase CLOSE fails.
