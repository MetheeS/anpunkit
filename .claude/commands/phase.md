---
description: Run one phase end-to-end. TDD phases run SPEC fill -> SPEC REVIEW -> SCAFFOLD -> RED -> conformance -> GREEN -> boundary/E2E; non-TDD phases run IMPLEMENT -> TEST. Both with the debug circuit breaker and the regression + dataflow + evidence guards at CLOSE.
argument-hint: [phase number]
---

compression: user (.claude/ref/compression.md). You are the ORCHESTRATOR. Route work to subagents —
you do NOT implement, fill specs, or debug yourself.

Note: subagents cannot talk to the user. Only YOU can.

Target phase: $ARGUMENTS  (default: the phase marked pending in docs/PLAN.md)

---

## 0. PRE-FLIGHT

a. INFRA CHECK (phases > 0): read docs/OVERVIEW.md `infra_needed`.
   - `infra_needed: false` -> no Phase 0 exists; SKIP this check entirely.
   - `infra_needed: true`: read docs/INFRA.md. If Phase 0 not done -> STOP.
     Tell me: "Phase 0 (infra) not complete. Run `/infra` first."
   - Exception: if $ARGUMENTS is "0", tell me to run `/infra` directly.

b. PHASE STATE CHECK: Read docs/STATE.md and docs/PLAN.md.
   - No phase in progress, requested is next pending -> START at step 1.
   - Same phase in-progress -> RESUME from STATE.md "next action".
   - Different phase in-progress -> STOP. Tell me which phase is open.
   - Out of dependency order -> STOP. Warn, proceed only if I confirm.
   - Phase not in PLAN.md -> STOP. Suggest /overview or /replan.

c. FINAL PHASE CHECK: Read docs/PLAN.md. Is this the last phase (no further
   pending phases after this one)? Record this as IS_FINAL_PHASE=true/false.

d. AUTH LIVENESS GATE (hard rule 16): only if this phase touches a credentialed
   external service and will run a boundary/E2E suite. Skip otherwise.
   - If INFRA.md has no `AUTH PROOF: PASS` marker -> STOP: "Auth never proven
     reusable. Run `/infra` first."
   - Run the liveness command recorded in docs/INFRA.md `## AUTH` (Azure projects:
     the ritual per `knowledge/azure.md`, i.e. `bash scripts/auth-setup.sh`) and,
     for each external system this phase touches (docs/DATAFLOW.md external rows +
     docs/ENDPOINTS.md auth column), confirm its credential is obtainable
     headlessly. Any failure -> boundary/E2E is BLOCKED; tell me what to run; the
     MOCK suite may still proceed.

e. FRONTEND TRIGGER (hard rule 13): read docs/OVERVIEW.md `has_frontend` + the
   frontend root. Set FRONTEND_PHASE=true iff `has_frontend: true` AND this
   phase's `changes` (docs/PLAN.md) include any path under the frontend root.
   This is a PATH MATCH, not a judgment call. Record FRONTEND_PHASE — it gates the
   `ui` boundary run + evidence at CLOSE.

f. FLAG BASELINES: read docs/OVERVIEW.md `e2e_kind` + `deploy_kind`. These are the
   project baselines; §1 binds this phase's effective E2E_KIND and (final phase)
   confirms DEPLOY_KIND.

---

## 1. RESEARCH + TDD APPLICABILITY

Dispatch `researcher` in IMPL mode scoped to this phase.
Returns terse summary + path. Read the file only if needed.
Unknowns block the phase -> re-dispatch narrowed. No guessing.

DATASOURCE DELTA (hard rule 15): if this phase tests against an external
datasource, compare what it touches to the confirmed BASELINE in
docs/research/datasource-<name>.md. If it touches a NEW table/column beyond the
baseline -> surface my understanding of just that delta as a falsifiable claim;
WAIT for confirm; append it to datasource-<name>.md. If it touches only confirmed
data -> proceed with a one-line note, no stop. Boundary/E2E against an UNCONFIRMED
datasource is HARD-BLOCKED (mock still runs). The confirmed baseline is what
`spec-author` grounds fixtures in.

Then classify the phase:

  `TDD_PHASE` = the phase adds or changes a PUBLIC CALLABLE SURFACE (endpoint,
  exported function/class, CLI command, message contract) assertable from the
  acceptance spec. Size is NOT the criterion.

- Clear public surface -> `TDD_PHASE=true` -> run the TDD path (§2 → §3 → §4 → §5 → §6 → §7).
- Pure infra/config/doc, no public surface -> `TDD_PHASE=false` -> run the
  non-TDD path (§2N → §3N).
- AMBIGUOUS -> default `TDD_PHASE=true`, but STATE the classification + the reason
  to me, so I can override to non-TDD BEFORE SPEC fill fires. (Hard rule 11: never
  downgrade a TDD phase just to dodge the gates.)

FLAG BINDING (hard rule 10): bind this phase's effective E2E_KIND — `browser` iff
FRONTEND_PHASE, else the OVERVIEW `e2e_kind` baseline. If IS_FINAL_PHASE, restate
`deploy_kind` and confirm the final phase's deploy task realizes it. STATE both
bindings. Divergence from OVERVIEW is mine to resolve — never silently re-derived.

=====================================================================
## TDD PATH  (TDD_PHASE=true)
=====================================================================

## 2. SPEC FILL + STALENESS

a. SKELETON CHECK: confirm docs/spec-phase-<n>.md exists (planner generated it at
   /overview). If MISSING (planner classified it non-TDD, or it's a new phase from
   /replan): generate the skeleton NOW from this phase's PLAN.md `acceptance` +
   `dataflow:` transitions in the planner skeleton format (generated header + named
   `TBD` rows), then `bash scripts/spec-staleness.sh stamp <n>` to stamp its hash.

b. Dispatch `spec-author`. It fills each case row with a real input payload
   (`fixtures/<case-id>-input.json`), concrete expected output
   (`fixtures/<case-id>-expected.json`), matcher tokens for volatile fields,
   `error-code` for failures, and `selector/assert/value` `ui` descriptors —
   grounded in the RESEARCH findings + the confirmed datasource baseline.

c. CASE-SET-DIVERGENCE (hard re-entry, hard rule 12 / §5.52): if `spec-author`
   returns `CASE-SET-DIVERGENCE` (a required case can't be filled from real facts,
   or research revealed an unlisted/contradicted case) -> STOP. Surface the finding.
   I amend the up-front case-name contract in the skeleton; you re-stamp
   (`bash scripts/spec-staleness.sh stamp <n>`); then re-dispatch `spec-author` to
   re-fill from scratch. AI never amends the case-name set — I own the contract.

d. STALENESS (hard rule 17): run `bash scripts/spec-staleness.sh <n>`. Nonzero
   (upstream PLAN acceptance line / DATAFLOW rows drifted since the skeleton was
   stamped, e.g. via /replan) -> regenerate the skeleton header from current
   PLAN/DATAFLOW, re-stamp, re-dispatch `spec-author`. Do NOT hand-edit the hash.

## 3. SPEC REVIEW — human gate (hard rule 12)

STOP. Surface the FILLED cases to me as FALSIFIABLE CLAIMS in plain language, e.g.:
  - "POST /orders/submit with an empty line-item list → 422 EMPTY_ORDER."
  - "Successful submit of a 3-line order → 201; order.id is a UUID; order.status is
    'submitted'."
Re-run `bash scripts/spec-staleness.sh <n>` at entry (nonzero -> back to §2d).
SCAFFOLD cannot begin until I confirm. Classify any rejection WITH me (§5.50):
  - WRONG EXPECTED -> fix the case row + `fixtures/<case-id>-expected.json`; no
    re-research. (You may patch the fixture directly per my correction.)
  - WRONG INPUT SHAPE -> re-dispatch `spec-author` with the correction.
  - NEW CASE or CONTRADICTED CASE -> hard re-entry (§2c): I amend the skeleton, you
    re-stamp, re-confirm the amended case(s) + any case sharing their `covers` id
    (the staleness hash certifies the unchanged remainder — not re-read), re-fill.
Loop until I approve. Unskippable on TDD phases.

## 4. SCAFFOLD

Dispatch `implementer` in SCAFFOLD mode: interface stubs only (signatures +
types; bodies raise NotImplementedError / return 501); NO logic, NO tests, NO
edits to the spec or fixtures. Returns the stub files + the interface surface.

## 5. RED

Dispatch `test-author` to EMIT the boundary harness from the locked spec `data`
rows: one deep-equality assertion per case against `fixtures/<case-id>-expected.json`
via the kit comparator `tests/helpers/spec-assert.*`, each citing its case with a
`# spec: <case-id>` comment. It does NOT author assertions — it generates them from
the spec. Place contract/ENDPOINTS/transition tests in `tests/regression/`,
phase-local in `tests/phase-<n>/`.

If FRONTEND_PHASE (and the phase has `ui` cases): also dispatch `e2e-runner` to EMIT
Playwright assertions from each `ui` case's `fixtures/<case-id>-ui.json` descriptor,
each citing `// spec: <case-id>`. Run the suites.

RED GATE = every case test COLLECTS cleanly AND FAILS (assertion / NotImplemented).
- Any test PASSES on stubs -> STOP (spec trivial or emitter wrong); show me.
- Collection / import / syntax error -> stub mismatch; re-dispatch SCAFFOLD to
  fix SIGNATURES (not logic); re-run.

## 6. CONFORMANCE GATE (hard rule 18) — replaces the v2.1 human TEST REVIEW

Run `bash scripts/spec-conformance.sh <n>`. It loud-fails (and BLOCKS GREEN) if:
  - any `TBD` marker remains in docs/spec-phase-<n>.md or a referenced fixture, OR
  - any case-id in the spec table has no boundary test citing it (`# spec: <case-id>`).
Nonzero -> fix the gap (re-dispatch `spec-author` for a stray TBD, or `test-author`/
`e2e-runner` for a missing citation) and re-run. GREEN cannot start until it passes.

## 7. GREEN + BOUNDARY/E2E

Dispatch `implementer` in FILL mode with the FILLED docs/spec-phase-<n>.md + its
fixtures + research + the generated test file paths (it MAY read the tests — frozen
before logic, no overfit — but must NOT edit tests, spec, or fixtures). Fill to
green against the spec. Budget 3, WARN@2, STUCK@3.

Run the BOUNDARY suite (real HTTP/CLI/message; `TEST_MODE=real`) — the outer surface
per this phase's bound E2E_KIND. Capture evidence (hard rule 13):
- `browser` (FRONTEND_PHASE): dispatch `e2e-runner` to run its emitted `ui` specs —
  MANDATORY — reads INFRA.md target, runs the stack ritual per `knowledge/webapp.md`
  (`scripts/e2e-stack.sh up` / Playwright / `down`), captures a screenshot at EACH
  UI-existence assertion regardless of pass/fail to docs/evidence/e2e-phase-<n>/,
  with a summary in docs/research/e2e-<slug>.md.
- `cli` / `http` / `library-api`: the real-mode boundary suite IS the outer run;
  capture its transcript (invocation + result) to docs/evidence/e2e-phase-<n>/.
  No separate emitter is dispatched.

PHASE GATE (rule 5) -> go to §8/§9/§10 (see GATE below).

=====================================================================
## NON-TDD PATH  (TDD_PHASE=false)
=====================================================================

## 2N. IMPLEMENT

Dispatch `implementer` (legacy mode) with phase spec + research summary.
Returns STUCK -> go to ESCALATE.
If IS_FINAL_PHASE: phase spec includes the deploy task; confirm the return
realizes `deploy_kind` (deployed URL / published version / verified install-run)
before proceeding.

## 3N. TEST (blind)

Dispatch `test-author`. It writes MOCK + boundary suites from the acceptance
spec — never reads the logic. (No spec file, SPEC REVIEW, or conformance gate on
the non-TDD path — no public surface to contract. e2e-runner only if FRONTEND_PHASE.)

=====================================================================

## GATE (both paths)

PHASE GATE = current-phase BOUNDARY suite passes AND (FRONTEND_PHASE) the `ui`
boundary passes WITH evidence captured AND the accumulated mock regression corpus
stays green AND every docs/ENDPOINTS.md entry has a regression test AND (TDD)
`spec-conformance.sh` passed AND every REACHABLE docs/DATAFLOW.md transition has a
filled case in the phase spec (all checked at CLOSE).
- GATE PASS -> go to CLOSE.
- GATE BLOCKED (SERVICE UNAVAILABLE, STACK NOT READY, AZURE UNAVAILABLE, FLAKE)
  -> tell me, wait. Not a code bug. For AZURE UNAVAILABLE: suggest `/infra verify`.
- GATE FAIL (LOGIC FAIL) -> go to FIX.

---

## 8. FIX

Dispatch `debugger` (isolated context) on the specific failure.
- FIXED -> re-run the boundary suite (and the regression corpus).
- SERVICE UNAVAILABLE -> tell me, wait. Suggest `/infra verify` if Azure.
- WARN (2 attempts failed) -> relay immediately, then let debugger finish attempt 3.
- STUCK -> go to ESCALATE.

---

## 9. ESCALATE — circuit breaker. Mode B.

FIRST STUCK: STOP. Present to me: the problem, 3 failed hypotheses, the
debugger's recommendation, the debug file path. Ask what to do. Wait. Options:
  (a) "re-research" -> /unstuck
  (b) hint -> re-dispatch debugger with hint, budget 3
  (c) "skip" / "re-slice" -> mark blocked, dispatch planner

SECOND STUCK: STOP completely. Full summary — every hypothesis, current state,
what to try next. Hand control to me.

---

## 10. CLOSE

REGRESSION + COVERAGE GATES (before closing — all FAIL HARD, do not close):
- Run `bash scripts/regression.sh` (mock corpus). A failure BLOCKS close -> route to FIX.
- ENDPOINTS COVERAGE: every `docs/ENDPOINTS.md` entry MUST have >=1 test in
  `tests/regression/`. Zero coverage -> FAIL HARD.
- DATAFLOW COVERAGE (hard rule 14, re-seamed v2.2): every `docs/DATAFLOW.md`
  transition whose trigger is REACHABLE in the code shipped so far MUST have >=1
  FILLED CASE in docs/spec-phase-<n>.md. Zero coverage on a reachable transition ->
  FAIL HARD. Unreachable transitions list as PENDING (not failed). IF
  IS_FINAL_PHASE: any transition still PENDING -> FAIL HARD. (The case→test half is
  already enforced by `spec-conformance.sh` at §6 — every case-id is cited by a
  boundary test, which by placement lands in tests/regression/.)
- EVIDENCE (hard rule 13): docs/evidence/e2e-phase-<n>/ must contain the boundary
  run's evidence — per-UI-existence-assertion screenshots for `browser`, or the
  captured boundary-run transcript for `cli`/`http`/`library-api`. Required whenever
  this phase closes an E2E_KIND boundary (browser: FRONTEND_PHASE; others: the phase
  ships/changes the outer surface). Empty when required -> FAIL HARD.
- IF IS_FINAL_PHASE: additionally run `bash scripts/regression.sh --real` (full real
  corpus). A failure blocks close.

Mark phase `done` in docs/PLAN.md.

ARCHITECTURE / DATAFLOW SELF-CHECK:
- Did this phase add/remove/rename an agent, hook, or command, or change a
  workflow rule? YES -> run `/log-decision`. NO -> state why not.
- Did this phase add/change an object's STATE LIFECYCLE? YES -> update
  docs/DATAFLOW.md (hard rule 9) in this CLOSE, and confirm new reachable
  transitions are covered by a filled case. NO -> state why not.

IF IS_FINAL_PHASE — FINAL CLOSE sequence:

  a. Run `/synthesize` — pass the signal that this is the final phase so the
     synthesizer runs the extended pass (OVERVIEW.md + README.md update).

  b. Surface a "READY TO USE" summary to me, shaped by `deploy_kind`:
     ```
     ✅ PROJECT COMPLETE

     <deploy_kind line:
       cloud-deploy         -> Deployed at: <base URL from docs/INFRA.md "Deployed base URL">
       package-publish       -> Published: <package name> @ <version> to <registry>
       install-run-verified  -> Verified install/run: <the exact commands, confirmed working>
       none(<reason>)        -> Not shipped: <reason>>

     ## Interface
     <web/http: paste the full docs/ENDPOINTS.md table; cli: the command surface;
      library: the public API surface>

     ## Quick start
     <how to use it, per deploy_kind — base URL + auth + health check for a service;
      install + invoke for a CLI; import + call for a library>

     ## Docs
     - Full interface catalogue: docs/ENDPOINTS.md
     - Object/state flow: docs/DATAFLOW.md
     - Infrastructure: docs/INFRA.md (if infra_needed)
     - Project history: docs/HISTORY.md
     ```
  Tell me the project is complete and ready to use.

ELSE (not final phase):

  Run `/synthesize`.
  Tell me phase done + the next phase. Recommend `/clear` then `/phase` next.

---

## STATE CHECKPOINTING

After each step, update docs/STATE.md:
```

phase: <n> (in progress)
tdd: <true|false>
frontend_phase: <true|false>
e2e_kind: <browser|cli|http|library-api — the bound value>
completed: <steps done so far>
next: <exact next step>
blocker: <none or open issue>

```
Keep STATE.md small — overwrite, do not append.
