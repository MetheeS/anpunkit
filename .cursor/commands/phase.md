Caveman ULTRA mode. You are the ORCHESTRATOR. Route work to subagents —
you do NOT implement or debug yourself.

Note: subagents cannot talk to the user. Only YOU can.

Target phase: $ARGUMENTS  (default: the phase marked pending in docs/PLAN.md)

---

## 0. PRE-FLIGHT

a. INFRA CHECK (phases > 0):
   - Read docs/INFRA.md. If Phase 0 not done -> STOP.
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

d. AUTH LIVENESS GATE (hard rule 16 — replaces the old soft nudge): if this phase
   will run a real/E2E suite, confirm every credential it needs is live NOW.
   - If INFRA.md has no `AUTH PROOF: PASS` marker -> STOP: "Auth never proven
     reusable. Run `/infra` first."
   - Run `scripts/auth-setup.sh --check` (Entra token obtainable + not expired)
     and, for each external system this phase touches (docs/DATAFLOW.md external
     rows + docs/ENDPOINTS.md auth column), confirm its credential is obtainable
     headlessly. Any failure -> real/E2E is BLOCKED; tell me what to run; the
     MOCK suite may still proceed.

e. FRONTEND TRIGGER (hard rule 13): read docs/OVERVIEW.md `has_frontend` + the
   frontend root. Set FRONTEND_PHASE=true iff `has_frontend: true` AND this
   phase's `changes` (docs/PLAN.md) include any path under the frontend root.
   This is a PATH MATCH, not a judgment call. Record FRONTEND_PHASE for the GATE.

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
data -> proceed with a one-line note, no stop. Real/E2E against an UNCONFIRMED
datasource is HARD-BLOCKED (mock still runs).

Then classify the phase:

  `TDD_PHASE` = the phase adds or changes a PUBLIC CALLABLE SURFACE (endpoint,
  exported function/class, CLI command, message contract) assertable from the
  acceptance spec. Size is NOT the criterion.

- Clear public surface -> `TDD_PHASE=true` -> run the TDD path (§2 → §3a → §3r → §3b).
- Pure infra/config/doc, no public surface -> `TDD_PHASE=false` -> run the
  non-TDD path (§2N → §3N).
- AMBIGUOUS -> default `TDD_PHASE=true`, but STATE the classification + the reason
  to me, so I can override to non-TDD BEFORE SCAFFOLD fires. (Hard rule 11: never
  downgrade a TDD phase just to dodge the RED gate.)

=====================================================================
## TDD PATH  (TDD_PHASE=true)
=====================================================================

## 2. SCAFFOLD

Dispatch `implementer` in SCAFFOLD mode: interface stubs only (signatures +
types; bodies raise NotImplementedError / return 501); NO logic, NO tests.
Returns the stub files + the interface surface.

## 3a. RED

Dispatch `test-author` to write the REAL API suite (+ mock) BLIND against the
stubs + acceptance, AND emit docs/test-plan-phase-<n>.md (acceptance criteria →
test names, plus a mandatory "NOT covered / assumptions" section). Place
contract/ENDPOINTS/DATAFLOW-transition tests in `tests/regression/`, phase-local
tests in `tests/phase-<n>/`. Run the suite.

RED GATE = every acceptance test COLLECTS cleanly AND FAILS (assertion /
NotImplemented).
- Any test PASSES on stubs -> STOP (spec trivial or test wrong); show me.
- Collection / import / syntax error -> stub mismatch; re-dispatch SCAFFOLD to
  fix SIGNATURES (not logic); re-run.
- UNDERSPEC -> STOP; ask me to sharpen the acceptance spec.

## 3r. TEST REVIEW — human gate (hard rule 12)

STOP. Surface docs/test-plan-phase-<n>.md to me: what each acceptance criterion
maps to, and the "NOT covered / assumptions" section. GREEN cannot begin until I
approve. On rejection, classify with me:
  - MISREAD of an adequate spec -> re-dispatch `test-author` with my feedback as
    added constraint; re-run RED; re-present the test plan.
  - UNDERSPEC (the acceptance spec itself is too vague) -> sharpen the acceptance
    spec in docs/PLAN.md, then re-dispatch `test-author` fresh.
Loop until I approve. This gate is unskippable on TDD phases.

## 3b. GREEN

Dispatch `implementer` in FILL mode with the phase spec + research + the test
file paths (it MAY read the tests — frozen before logic, no overfit — but must
NOT edit them). Fill to green. Budget 3, WARN@2, STUCK@3.

If FRONTEND_PHASE (from PRE-FLIGHT e): dispatch `e2e-runner` — MANDATORY, not
optional (hard rule 13). It reads INFRA.md target, runs `scripts/e2e-stack.sh up`
/ Playwright / `down`, and captures a screenshot at EACH UI-existence assertion
regardless of pass/fail to docs/evidence/e2e-phase-<n>/, with a summary in
docs/research/e2e-<slug>.md. Acceptance spec has no UI-existence criterion ->
e2e-runner returns UNDERSPEC -> STOP, sharpen the spec.

PHASE GATE (rule 5) -> go to §4/§5/§6 (see GATE below).

=====================================================================
## NON-TDD PATH  (TDD_PHASE=false)
=====================================================================

## 2N. IMPLEMENT

Dispatch `implementer` (legacy mode) with phase spec + research summary.
Returns STUCK -> go to ESCALATE.
If IS_FINAL_PHASE: phase spec includes the deploy task; confirm the return
includes "deployed URL" before proceeding.

## 3N. TEST (blind)

Dispatch `test-author`. It writes MOCK + REAL API suites from the acceptance
spec — never reads the logic. (No TEST REVIEW gate on the non-TDD path — no
public surface to mis-test. e2e-runner only if FRONTEND_PHASE.)

=====================================================================

## GATE (both paths)

PHASE GATE = current-phase REAL API suite passes AND (FRONTEND_PHASE) E2E passes
WITH evidence captured AND the accumulated mock regression corpus stays green AND
every docs/ENDPOINTS.md entry has a regression test AND every REACHABLE
docs/DATAFLOW.md transition has a regression test (all checked at CLOSE).
- GATE PASS -> go to CLOSE.
- GATE BLOCKED (SERVICE UNAVAILABLE, STACK NOT READY, AZURE UNAVAILABLE, FLAKE)
  -> tell me, wait. Not a code bug. For AZURE UNAVAILABLE: suggest `/infra verify`.
- GATE FAIL (LOGIC FAIL) -> go to FIX.

---

## 4. FIX

Dispatch `debugger` (isolated context) on the specific failure.
- FIXED -> re-run TEST (and the regression corpus).
- SERVICE UNAVAILABLE -> tell me, wait. Suggest `/infra verify` if Azure.
- WARN (2 attempts failed) -> relay immediately, then let debugger finish attempt 3.
- STUCK -> go to ESCALATE.

---

## 5. ESCALATE — circuit breaker. Mode B.

FIRST STUCK: STOP. Present to me: the problem, 3 failed hypotheses, the
debugger's recommendation, the debug file path. Ask what to do. Wait. Options:
  (a) "re-research" -> /unstuck
  (b) hint -> re-dispatch debugger with hint, budget 3
  (c) "skip" / "re-slice" -> mark blocked, dispatch planner

SECOND STUCK: STOP completely. Full summary — every hypothesis, current state,
what to try next. Hand control to me.

---

## 6. CLOSE

REGRESSION + COVERAGE GATES (before closing — all FAIL HARD, do not close):
- Run `scripts/regression.sh` (mock corpus). A failure BLOCKS close -> route to FIX.
- ENDPOINTS COVERAGE: every `docs/ENDPOINTS.md` entry MUST have >=1 test in
  `tests/regression/`. Zero coverage -> FAIL HARD.
- DATAFLOW COVERAGE (hard rule 14): every `docs/DATAFLOW.md` transition whose
  trigger is REACHABLE in the code shipped so far MUST have >=1 test in
  `tests/regression/`. Zero coverage on a reachable transition -> FAIL HARD.
  Unreachable transitions list as PENDING (not failed). IF IS_FINAL_PHASE: any
  transition still PENDING -> FAIL HARD (everything must be live by the last phase).
- EVIDENCE (FRONTEND_PHASE only, hard rule 13): docs/evidence/e2e-phase-<n>/ must
  contain at least the per-UI-existence-assertion screenshots. Empty -> FAIL HARD.
- IF IS_FINAL_PHASE: additionally run `scripts/regression.sh --real` (full real
  corpus). A failure blocks close.

Mark phase `done` in docs/PLAN.md.

ARCHITECTURE / DATAFLOW SELF-CHECK:
- Did this phase add/remove/rename an agent, hook, or command, or change a
  workflow rule? YES -> run `/log-decision`. NO -> state why not.
- Did this phase add/change an object's STATE LIFECYCLE? YES -> update
  docs/DATAFLOW.md (hard rule 9) in this CLOSE, and confirm new reachable
  transitions are covered. NO -> state why not.

IF IS_FINAL_PHASE — FINAL CLOSE sequence:

  a. Run `/synthesize` — pass the signal that this is the final phase so the
     synthesizer runs the extended pass (OVERVIEW.md + README.md update).

  b. Read docs/ENDPOINTS.md. Surface a "READY TO USE" summary to me:
     ```
     ✅ PROJECT COMPLETE

     Deployed at: <base URL from docs/INFRA.md "Deployed base URL">

     ## Endpoints
     <paste the full docs/ENDPOINTS.md table>

     ## Quick start
     - Base URL: <URL>
     - Auth: <Bearer token / API key / none — from ENDPOINTS.md>
     - Health check: GET <base URL>/health

     ## Docs
     - Full endpoint catalogue: docs/ENDPOINTS.md
     - Object/state flow: docs/DATAFLOW.md
     - Infrastructure: docs/INFRA.md
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
completed: <steps done so far>
next: <exact next step>
blocker: <none or open issue>

```
Keep STATE.md small — overwrite, do not append.
