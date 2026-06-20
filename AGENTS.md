# anpunkit — portable agent methodology (single source of truth)

<!-- ANPUNKIT-AGENTS-SENTINEL-v2.1 -->
> **SENTINEL.** The HTML comment above (`ANPUNKIT-AGENTS-SENTINEL-v2.1`) is a
> load-bearing marker. `setup.sh` greps for it to confirm this file resolved on
> disk and was not clobbered. Do not remove or rename it.

> **What this file is.** The complete, tool-agnostic methodology for the anpunkit
> workflow: the loop, the roles, the procedures, the rituals, and the hard rules.
> This is the ONE place every rule lives. Claude Code, Cursor, and any tool that
> reads the open `AGENTS.md` standard get the full methodology from here.

> **Anti-drift invariant (load-bearing).** Every rule lives in exactly ONE place:
> this file. `CLAUDE.md` restates NO rule — it only maps roles to Claude-native
> files and says "native mechanism X performs ritual Y automatically." A rule and
> its automation may never contradict. Duplication between files is an
> architectural defect, not a convenience.

Caveman ULTRA mode always on. Apply the `karpathy-guidelines` skill (engineering
discipline) on every coding and debugging task.

-----

## The loop

`design-research -> grill (×2) -> plan -> implement -> test -> deploy`, one
VERTICAL SLICE per phase. Implement AND test a phase before the next. The last
phase always includes deployment.

A phase runs in one of two orders, chosen at RESEARCH time by the TDD
APPLICABILITY check (see Procedures → `phase`):

- **TDD phase** (`TDD_PHASE=true`):
  `RESEARCH -> SCAFFOLD -> RED -> TEST REVIEW -> GREEN -> E2E -> FIX -> CLOSE`
- **Non-TDD phase** (pure infra / config / doc — `TDD_PHASE=false`):
  `RESEARCH -> IMPLEMENT -> TEST -> FIX -> CLOSE`

`TDD_PHASE` = "the phase adds or changes a public callable surface (an endpoint,
exported function/class, CLI command, or message contract) that is assertable
from the acceptance spec." Size is NOT the criterion. On ambiguity, default
`TDD_PHASE=true` AND state the classification + reason so a human can override to
non-TDD before SCAFFOLD fires.

**TEST REVIEW (v2.1)** is a mandatory human gate on every TDD phase, sitting
between RED and GREEN. After `test-author` writes the suite it emits a
`docs/test-plan-phase-<n>.md` (acceptance criteria → test names, plus a mandatory
"NOT covered / assumptions" section). The orchestrator surfaces it; FILL cannot
fire until the human approves. A rejected coverage map is classified at the gate:
a misread of an adequate spec → re-dispatch `test-author` with feedback; an
underspecified acceptance spec → sharpen `PLAN.md` and re-dispatch fresh. The gate
is unskippable on TDD phases and absent on the non-TDD path (no public surface to
mis-test). This is the fix for "all tests green, core still broken." (§5.33)

**E2E is mandatory, not a judgment call (v2.1).** If the project is frontend-bearing
(`has_frontend: true` in `docs/OVERVIEW.md`) AND the phase's `changes` touch the
frontend root recorded in OVERVIEW.md, `e2e-runner` MUST run before CLOSE. The
trigger is a deterministic path match, not "does this phase feel frontend-y." A
frontend file changed with no E2E run is a loud CLOSE failure. (§5.34)

-----

## Roles (fresh-context workers)

Each role is a fresh-context worker. Where the host tool supports named subagents
(Claude Code natively; Cursor reads the same `.claude/agents/` files via its
Claude-compatibility path), each maps to a definition file. Where it does not, the role
degrades to a bounded sub-task that dumps its noise to a file and returns only a
terse summary + path. Workers cannot address the user — only the orchestrator
can. Escalation is at most two hops.

- **researcher** — two modes. DESIGN: domain/constraint research before planning
  (service limits, API contracts, architectural constraints, cost surprises);
  for any external datasource, drafts a falsifiable DATA UNDERSTANDING (grain,
  fields-under-test with meaning + real nullability/range, sample-fixture shape,
  the assumption that if wrong makes a test meaningless) to `docs/research/
  datasource-<name>.md`. IMPL: per-phase codebase + service investigation. Checks
  the shared KB snapshot first (step 0). Writes findings to `docs/research/`;
  returns terse summary + path.
- **planner** — research → vertical-slice `docs/PLAN.md`. Phase 0 (infra) always
  first; the last phase always contains the deploy task. For any phase whose
  `changes` touch the frontend root, the `acceptance` MUST include ≥1 UI-existence
  criterion naming the specific user-visible interactive element introduced (not
  "page renders 200"). Populates each phase's expected `DATAFLOW.md` transitions.
- **infra-provisioner** — generates Bicep, runs `az deployment what-if`, applies
  only on human approval, writes `docs/INFRA.md` + `.env.test`. Runs the one-time
  AUTH PROOF (§5.37): proves every credential the project's real tests will use is
  obtainable headlessly twice in a row (prime + reuse) with zero prompts.
- **implementer** — builds ONE phase. Two MODES for TDD phases (SCAFFOLD: stubs
  only; FILL: logic to green) plus a legacy full-build mode for non-TDD phases.
  Writes code, never tests. Maintains `docs/ENDPOINTS.md` each phase.
- **test-author** — writes tests BLIND (never reads implementation logic). On TDD
  phases it is dispatched BEFORE logic exists (RED-first), so blindness is
  structural, not honor-system. Writes a MOCK suite + a REAL API suite, and emits
  `docs/test-plan-phase-<n>.md` (the TEST REVIEW artifact) with a mandatory "NOT
  covered / assumptions" section. For phases touching an external datasource,
  surfaces any DATA UNDERSTANDING delta (new table/column beyond the confirmed
  baseline) for confirmation before the real suite runs.
- **e2e-runner** — writes/runs functional browser E2E (Playwright) BLIND. Reads
  `docs/INFRA.md` for the target. Captures a screenshot at EACH UI-existence
  assertion regardless of pass/fail (capture-on-success, not just on-failure) to
  `docs/evidence/e2e-phase-<n>/`, plus a summary in `docs/research/e2e-<slug>.md`.
- **debugger** — debugs in an ISOLATED context. Writes a trace to
  `docs/research/debug-<slug>.md`; returns a summary.
- **synthesizer** — compresses `docs/STATE.md` / `docs/ISSUES.md`, prunes
  snapshots. On the final phase, also updates `README.md` + `docs/OVERVIEW.md`.

The orchestrator ROUTES. It does not implement or debug.

-----

## Procedures (the slash-command set)

Named procedures, each with a canonical body in `commands.src/<name>.md` and a
generated copy per tool (`.claude/commands/`, `.cursor/commands/`).

- **overview** — bootstrap a project: design-research → grill r1 → design-research
  → RESEARCH REVIEW → re-grill r2 (covers data structures, dataflow, and object
  state flow) → `OVERVIEW.md` (+ `has_frontend`/frontend-root, `DATAFLOW.md`,
  confirmed datasource understanding) → planner → `PLAN.md` (Phase 0 always first).
- **infra** — provision/verify Azure infra: Bicep → what-if → human review → apply
  → `INFRA.md` + `.env.test`. Runs the one-time AUTH PROOF.
- **phase [n]** — run one phase end-to-end with the circuit breaker. Chooses the
  TDD or non-TDD order at RESEARCH. PRE-FLIGHT runs the auth liveness check. TDD
  phases stop at TEST REVIEW before GREEN. Frontend phases run mandatory E2E with
  screenshot evidence. CLOSE runs the regression guard + ENDPOINTS coverage gate +
  DATAFLOW transition-coverage gate + evidence-present check.
- **quick [change]** — small, obvious, non-phase change; no agent chain. Stays
  non-TDD. Runs the mock regression corpus after the change.
- **unstuck** — deep re-research after a circuit breaker (human-triggered).
- **synthesize** — compress STATE.md, dedup ISSUES.md, prune snapshots. Run
  before a context reset.
- **replan** — revise `PLAN.md` (add/cut/split/merge/reorder pending phases) and
  reconcile the regression corpus in step.
- **log-issue** — append an error to `ISSUES.md` with root cause + failed attempts.
- **log-decision** — record an architectural change in `docs/DESIGN_LOG.md`.
- **store-wisdom** — promote resolved issues + research to the shared KB.

-----

## Rituals (model-run fallback for hooks)

Where the host tool can run lifecycle hooks (Claude Code, Cursor), these rituals
are AUTOMATED by hook scripts and must NOT be run by hand. Where the tool cannot
inject context, the model performs them itself.

### SESSION-OPEN (start / clear / compact-resume)

At the start of every session, before any other work, surface:
1. git state (branch, uncommitted count, last 3 commits).
2. `docs/STATE.md` — the current position. READ THIS FIRST.
3. open items in `docs/ISSUES.md`.
4. `docs/research/INDEX.md` (research map) + infra status + auth nudge.
5. shared KB: pull latest + load `docs/.kb-snapshot.md` if `.claude/kb-config.json`
   exists.
6. a one-line reminder of the hard rules below.

### COMPRESS (before a context compaction)

Snapshot the live position to `docs/.snapshots/` so a post-compact session can
recover: current phase, next action, open blocker.

-----

## Hard rules (1–16)

1. Before debugging ANY error: grep `docs/ISSUES.md` AND `docs/research/INDEX.md`.
   The SESSION-OPEN ritual surfaces ISSUES.md — there is no excuse to miss it.
2. Debug attempt cap = 3: WARN the user at attempt 2; the FIRST hard-stop at 3
   STOPS and asks the user. No 4th in-place attempt.
3. Every resolved error -> logged to `docs/ISSUES.md` with root cause + failed
   attempts.
4. End of phase -> synthesize -> context reset -> next phase.
5. **PHASE GATE** = the current-phase REAL API suite passes AND (frontend phase)
   the E2E suite passes with screenshot evidence captured AND the accumulated mock
   regression corpus stays green AND every `docs/ENDPOINTS.md` entry has at least
   one test in `tests/regression/` AND every REACHABLE `docs/DATAFLOW.md` transition
   has at least one test in `tests/regression/`. The final phase additionally runs
   the full REAL regression corpus and requires zero PENDING transitions. A green
   mock suite alone can never close a phase.
6. Tests are written by `test-author`, which never sees the implementation logic
   (unbiased). On TDD phases the suite is written before the logic (RED-first).
7. Service outage is not a bug — `SERVICE UNAVAILABLE` / `AZURE UNAVAILABLE` /
   `STACK NOT READY` / `FLAKE` do not spend the debug budget. Only `LOGIC FAIL`
   reaches the debugger.
8. E2E auth = ROPC with a dedicated MFA-excluded test account. NEVER script the
   Microsoft login UI.
9. Architectural change (new/removed agent, hook, command, or a changed workflow
   rule)? -> run `log-decision` before closing. A phase that changes an object's
   state lifecycle MUST update `docs/DATAFLOW.md` in the same CLOSE.
10. Azure project? Run `scripts/auth-setup.sh` ONCE per session before any Azure
    work. Never debug an auth error without checking this first.
11. **No-rationalization (scoped).** Do not, in order to dodge a gate:
    downgrade a TDD phase to non-TDD or route phase-worthy work through `quick`
    (RED gate); set `has_frontend: false` or keep a touched element out of the
    acceptance spec (E2E / UI-existence gate); mark a reachable transition PENDING
    (DATAFLOW gate); or skip evidence capture. (Scoped deliberately to these named
    seams; this is not a broad "never make excuses" rule.)
12. **TEST REVIEW (TDD phases).** GREEN cannot begin until the human approves
    `docs/test-plan-phase-<n>.md`. Rejection is classified at the gate (misread
    spec → re-dispatch test-author with feedback; underspec → sharpen PLAN.md and
    re-dispatch fresh). Unskippable on TDD phases; absent on the non-TDD path.
13. **Mandatory frontend E2E + evidence.** When `has_frontend: true` and the
    phase's `changes` touch the frontend root recorded in OVERVIEW.md, E2E MUST
    run. Each UI-existence assertion captures a screenshot (on success too) to
    `docs/evidence/e2e-phase-<n>/`. Frontend files changed with no E2E run, or a
    closed frontend phase with no evidence on disk, fails CLOSE hard. (Evidence is
    gitignored — present-on-disk at CLOSE is the check, not committed history.)
14. **DATAFLOW transition coverage.** Every transition in `docs/DATAFLOW.md` whose
    trigger is reachable in the code shipped so far MUST have ≥1 test in
    `tests/regression/`; zero coverage on a reachable transition fails CLOSE hard.
    Unreachable transitions list as PENDING. Any transition still PENDING at the
    final phase fails hard. Peer to the ENDPOINTS coverage gate.
15. **Datasource data understanding.** Real-suite / E2E tests against an external
    datasource are HARD-BLOCKED until that datasource's DATA UNDERSTANDING is
    confirmed (baseline at `/overview`; per-phase delta-confirm for any
    new table/column). The mock suite still runs. No testing against data you
    never confirmed understanding of.
16. **Auth proof + liveness.** A one-time AUTH PROOF at `/infra` proves every
    credential the real tests use — Entra/MSAL app login AND external datasource
    credentials — is obtainable headlessly twice in a row (prime + reuse) with
    zero prompts; "reusable without interaction" means exactly this. Each `/phase`
    PRE-FLIGHT runs a cheap liveness check (token obtainable, not expired) before
    dispatching real/E2E. Both fail loud; the mock suite proceeds regardless.

-----

## Shared KB (optional)

If `.claude/kb-config.json` exists, the SESSION-OPEN ritual pulls the KB and loads
a snapshot to `docs/.kb-snapshot.md`. The researcher checks the snapshot (step 0)
before any web search. Run `store-wisdom` to promote resolved issues + research to
the KB. The kit works normally without a KB.

-----

## File contract

- `docs/STATE.md` — current position. Small. Rewritten, not appended.
- `docs/ISSUES.md` — error log. Deduped by synthesizer.
- `docs/PLAN.md` — the phase plan. Phase 0 (infra) always first; last phase has
  the deploy task.
- `docs/HISTORY.md` — one line per finished phase.
- `docs/DESIGN_LOG.md` — kit architectural rationale (§5.x decision log).
- `docs/OVERVIEW.md` — project scope. Written after the double-grill in `overview`.
  Carries `has_frontend` + the frontend root path, and the data/state-flow summary.
- `docs/DATAFLOW.md` — state-transition table per key object (`object | states |
  transition (from→to) | trigger | who writes | external system`). Living doc,
  grill-driven; drives the CLOSE transition-coverage gate. The data-side analogue
  of `ENDPOINTS.md`. (v2.1)
- `docs/test-plan-phase-<n>.md` — the TEST REVIEW artifact: acceptance → test names
  + mandatory "NOT covered / assumptions" section. Human-approved before GREEN. (v2.1)
- `docs/evidence/e2e-phase-<n>/` — screenshot evidence captured at each UI-existence
  assertion (gitignored; present-on-disk at CLOSE is the gate). (v2.1)
- `docs/INFRA.md` — Azure infra manifest: resource IDs, endpoints, cost estimates,
  E2E target, AUTH PROOF result.
- `docs/ENDPOINTS.md` — API/service endpoint catalogue. Maintained by implementer
  each phase. Drives the CLOSE coverage gate.
- `docs/research/` — full research + debug files. `INDEX.md` is the searchable map.
  `design-<slug>.md` (design research), `<slug>.md` (impl research),
  `debug-<slug>.md` (debugger traces), `datasource-<name>.md` (confirmed data
  understanding, referenced from DATAFLOW.md external rows).
- `docs/.snapshots/` — pre-compact recovery markers (auto-pruned, gitignored).
- `infra/` — Bicep templates. Committed (IaC audit trail). `infra/params.json`
  holds no secrets.
- `e2e/`, `scripts/e2e-stack.sh`, `docker-compose.test.yml`, `playwright.config.ts`
  — the E2E stack.
- `tests/phase-<n>/` — phase-local test suites.
- `tests/regression/` — cross-phase contract tests (the regression corpus). Run by
  `scripts/regression.sh` (default mock; `--real` runs the real corpus).
- `scripts/auth-setup.sh` — session Azure credential check. Run once per session.
- `.claude/kb-config.json` — shared KB path + remote (optional, written by setup.sh).
- `docs/.kb-snapshot.md` — KB INDEX loaded this session (auto-generated, gitignored).

-----

## Capability matrix (which tools get what)

- **Claude Code — full (reference implementation).** Generated commands; all three
  lifecycle hooks WITH context injection (SessionStart / PreCompact / SubagentStop);
  named subagents (`.claude/agents/*.md`); `@AGENTS.md` import; shared KB.
- **Cursor — full (verified against cursor.com/docs, 2026-06).** Generated
  commands (`.cursor/commands/`); the three lifecycle hooks via `.cursor/hooks.json`
  (sessionStart / preCompact / subagentStop) wired to the SAME shared hook scripts —
  sessionStart injects context via a JSON-envelope wrapper
  (`cursor-session-start.sh`); named subagents work natively because Cursor reads
  `.claude/agents/*.md` directly (no duplication); methodology via a
  `.cursor/rules/` pointer at this file. Known degradations: `model: haiku/opus`
  tiers are Claude-specific (Cursor falls back to inherit/compatible), and Cursor's
  preCompact is observational (the snapshot side-effect still runs; no context
  modification).
- **Everything else.** Reads this `AGENTS.md` if it supports the open standard.
  No generated adapters. Not claimed as supported in v2.0.
