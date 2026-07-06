# anpunkit — portable agent methodology (single source of truth)

<!-- ANPUNKIT-AGENTS-SENTINEL-v2.3 -->
> **SENTINEL.** The HTML comment above (`ANPUNKIT-AGENTS-SENTINEL-v2.3`) is a
> load-bearing marker. `setup.sh` greps for the bare prefix `ANPUNKIT-AGENTS-SENTINEL`
> to confirm this file resolved on disk and was not clobbered. Do not remove or
> rename it.

> **What this file is.** The complete, tool-agnostic methodology for the anpunkit
> workflow: the loop, the roles, the procedures, the rituals, and the hard rules.
> This is the ONE place every rule lives. Claude Code reads the full methodology
> from here (as can any tool supporting the open `AGENTS.md` standard). v2.3 is
> Claude Code only.

> **Anti-drift invariant (load-bearing).** Every rule lives in exactly ONE place:
> this file. `CLAUDE.md` restates NO rule — it only maps roles to Claude-native
> files and says "native mechanism X performs ritual Y automatically." A rule and
> its automation may never contradict. Duplication between files is an
> architectural defect, not a convenience.

Compression is always on: profile `user` from `.claude/ref/compression.md`
governs all human-facing output; every subagent prompt declares profile
`internal`. Apply the `karpathy-guidelines` skill (engineering discipline) on
every coding and debugging task.

-----

## The loop

`design-research -> grill (×2) -> plan -> implement -> test -> deploy`, one
VERTICAL SLICE per phase. Implement AND test a phase before the next. The last
phase always includes DEPLOY_KIND completion.

A phase runs in one of two orders, chosen at RESEARCH time by the TDD
APPLICABILITY check (see Procedures → `phase`):

- **TDD phase** (`TDD_PHASE=true`):
  `RESEARCH -> SPEC fill -> spec-staleness -> SPEC REVIEW -> SCAFFOLD -> RED -> spec-conformance -> GREEN -> boundary/E2E -> FIX -> CLOSE`
- **Non-TDD phase** (pure infra / config / doc — `TDD_PHASE=false`):
  `RESEARCH -> IMPLEMENT -> TEST -> FIX -> CLOSE`

`TDD_PHASE` = "the phase adds or changes a public callable surface (an endpoint,
exported function/class, CLI command, or message contract) that is assertable
from the acceptance spec." Size is NOT the criterion. On ambiguity, default
`TDD_PHASE=true` AND state the classification + reason so a human can override to
non-TDD before SPEC fill fires.

**Project flags (adaptive loop, hard rule 10).** DECLARED once at `/overview` and
recorded in `docs/OVERVIEW.md`: `project_type`, `has_frontend` (+ root),
`infra_needed`, `e2e_kind` (browser | cli | http | library-api), `deploy_kind`
(cloud-deploy | package-publish | install-run-verified | none), `knowledge_docs`.
Per-phase bindings happen at RESEARCH (same idiom as `TDD_PHASE`): the effective
`E2E_KIND` (browser iff the phase is a frontend phase, else the baseline) and,
on the final phase, `DEPLOY_KIND` confirmation. Derivation is deterministic
(tables live in `commands.src/overview.md`); nothing is inferred mid-phase.
These branch the loop: Phase 0 exists iff `infra_needed`; the boundary run is
selected by `E2E_KIND`; the final phase completes `DEPLOY_KIND`.

**SPEC REVIEW (v2.2)** is the mandatory human gate on every TDD phase, sitting
UPSTREAM — between RESEARCH and SCAFFOLD, before any code. The reviewable,
authoritative artifact is the SPEC, not the test. After RESEARCH, `spec-author`
fills `docs/spec-phase-<n>.md` (skeleton case-names generated at `/overview`) with
concrete observable behavior — real input payloads, real expected outputs, matcher
tokens for volatile fields — grounded in fresh per-phase research and the confirmed
datasource baseline. `scripts/spec-staleness.sh` then loud-fails if the upstream
`acceptance:` line or `DATAFLOW.md` transition rows drifted since the skeleton was
generated. The orchestrator surfaces the filled cases as FALSIFIABLE CLAIMS
("POST /orders/submit with an empty line-item list → 422 EMPTY_ORDER"); SCAFFOLD
cannot fire until the human confirms. Rejection is classified at the gate (§5.50):
wrong expected → fix the case row + fixture; wrong input shape → re-dispatch
`spec-author`; a new or contradicted case → hard re-entry to amend the up-front
case-name contract (§5.52). Tests are then GENERATED from the locked spec rows
(deep-equality + matcher tokens for `data`; Playwright from the descriptor for
`ui`) — humans never review test code. This is the fix for "both agents
independently fabricated the same wrong contract from a one-line acceptance and the
suite went green on a broken core." (§5.43–§5.50)

**Boundary test is the system-of-record per case (v2.2).** Every spec case has
exactly one OUTER-BOUNDARY test — `data` cases: a real HTTP call / CLI invocation /
real message against the running backend + real services (v2.1's "real API suite");
`ui` cases: a Playwright assertion against the deployed (or local-docker) target
(v2.1's "E2E"). The boundary test is the phase gate; green mock alone never closes a
phase. A mock mirror is optional and shares the SAME fixture + comparator via a
`TEST_MODE` flag, so it cannot assert different values than the boundary test. (§5.47)

**The boundary run is mandatory, not a judgment call (per E2E_KIND).** Every phase
that ships or changes its outer surface MUST run the boundary suite before CLOSE,
selected by the phase's bound `E2E_KIND`. **Browser** (`has_frontend: true` AND the
phase's `changes` touch the frontend root recorded in OVERVIEW.md — a deterministic
path match, not "does this feel frontend-y"): `ui` boundary cases MUST run; a
frontend file changed with no `ui` boundary run is a loud CLOSE failure. `e2e-runner`
EMITS the Playwright assertion from each case's `ui` descriptor (it no longer authors
blind) and retains screenshot-on-each-UI-existence-assertion as the visual backstop
(browser practice + stack ritual: `knowledge/webapp.md`). **cli / http /
library-api**: the phase's real-mode boundary suite is the outer run, executed
against the shipped artifact with its transcript captured as evidence. On a project
whose `e2e_kind` is not `browser` there is no browser: `ui` case rows are invalid.
(§5.34, §5.54, §5.65)

-----

## Roles (fresh-context workers)

Each role is a fresh-context worker. On Claude Code each maps to a named subagent
definition file (`.claude/agents/*.md`). Each worker dumps its noise to a file and
returns only a terse summary + path. Workers cannot address the user — only the
orchestrator can. Escalation is at most two hops.

- **researcher** — two modes. DESIGN: domain/constraint research before planning
  (service limits, API contracts, architectural constraints, cost surprises);
  for any external datasource, drafts a falsifiable DATA UNDERSTANDING (grain,
  fields-under-test with meaning + real nullability/range, sample-fixture shape,
  the assumption that if wrong makes a test meaningless) to `docs/research/
  datasource-<name>.md`. IMPL: per-phase codebase + service investigation. Checks
  the shared KB snapshot first (step 0). Writes findings to `docs/research/`;
  returns terse summary + path.
- **planner** — research → vertical-slice `docs/PLAN.md`. Phase 0 (infra) first
  iff `infra_needed: true`; the last phase always completes `deploy_kind`. For any
  phase whose `changes` touch the frontend root, the `acceptance` MUST include ≥1
  UI-existence
  criterion naming the specific user-visible interactive element introduced (not
  "page renders 200"). Populates each phase's expected `DATAFLOW.md` transitions.
  At `/overview` it ALSO enumerates the up-front CASE-NAME contract (§5.44): for
  every `DATAFLOW.md` transition and every `acceptance:` criterion in a TDD phase,
  the case *names* that must exist (happy path, each named edge, each named failure
  + error code) — no fixture values yet — written as skeleton `docs/spec-phase-<n>.md`
  files (generated header + named rows, values `TBD`).
- **spec-author** — fills the per-phase spec. Runs AFTER RESEARCH, BEFORE SPEC
  REVIEW. Reads the skeleton `spec-phase-<n>.md`, the confirmed
  `datasource-<name>.md` baseline, and per-phase RESEARCH for the real API shape;
  fills each case row with a real input payload (`fixtures/<case-id>-input.json`),
  concrete expected output (`fixtures/<case-id>-expected.json`), matcher tokens for
  volatile fields, `error-code` for failures, and `selector/assert/value` for `ui`
  cases. Returns `CASE-SET-DIVERGENCE` if a required case cannot be filled from real
  facts, or research reveals an unlisted branch/failure-mode. `spec-author` is NOT
  `implementer` (author ≠ implementer invariant, §5.53) and never reads
  implementation logic.
- **infra-provisioner** — dispatched only when `infra_needed: true` (Phase 0).
  Generates IaC, runs the provider's what-if/plan diff, applies only on human
  approval, writes `docs/INFRA.md` + `.env.test`. Runs the one-time AUTH PROOF
  (§5.37): proves every credential the project's real tests will use is obtainable
  headlessly twice in a row (prime + reuse) with zero prompts. Cloud-specific
  practice (Azure Bicep/`az`, Entra/MSAL) lives in `knowledge/azure.md`.
- **implementer** — builds ONE phase. Two MODES for TDD phases (SCAFFOLD: stubs
  only; FILL: logic to green) plus a legacy full-build mode for non-TDD phases.
  Writes code, never tests. On TDD phases it reads the human-approved filled
  `docs/spec-phase-<n>.md` as its behavioral contract (normal spec-driven
  development) — it never authors spec fixtures (author ≠ implementer, §5.53).
  Maintains `docs/ENDPOINTS.md` each phase.
- **test-author** — now a HARNESS EMITTER, not a blind assertion author (§5.53). On
  TDD phases it reads the locked spec rows and GENERATES the assertion harness: one
  deep-equality assertion against `fixtures/<case-id>-expected.json` per `data` case,
  citing the case with a `# spec: <case-id>` comment, using the kit-versioned
  comparator `tests/helpers/spec-assert.*` (which honors matcher tokens). It does
  not invent assertions — there is nothing for a human to review at the test layer.
  Places contract/transition tests in `tests/regression/`, phase-local in
  `tests/phase-<n>/`; mock-vs-boundary is a `TEST_MODE` flag on the SAME test.
- **e2e-runner** — the browser boundary emitter (E2E_KIND `browser`), dispatched
  only for frontend phases; a Playwright EMITTER for `ui` boundary cases, not a
  blind author (§5.54). Reads `docs/INFRA.md` for the target and each `ui` case's
  `fixtures/<case-id>-ui.json` descriptor (`selector / assert / value`, closed
  vocabulary: `visible | text-equals | enabled | count`), and emits the assertion.
  Captures a screenshot at EACH UI-existence assertion regardless of pass/fail
  (capture-on-success) to `docs/evidence/e2e-phase-<n>/`, plus a summary in
  `docs/research/e2e-<slug>.md`. Stack ritual + config templates: `knowledge/webapp.md`.
  (Non-browser E2E_KINDs — cli/http/library-api — have no separate emitter; the
  real-mode boundary suite is the outer run.)
- **debugger** — debugs in an ISOLATED context. Writes a trace to
  `docs/research/debug-<slug>.md`; returns a summary.
- **synthesizer** — compresses `docs/STATE.md` / `docs/ISSUES.md`, prunes
  snapshots. On the final phase, also updates `README.md` + `docs/OVERVIEW.md`.

The orchestrator ROUTES. It does not implement or debug.

-----

## Procedures (the slash-command set)

Named procedures, each with a canonical body in `commands.src/<name>.md`, copied
to `.claude/commands/` at install.

- **overview** — bootstrap a project: design-research → grill r1 → design-research
  → RESEARCH REVIEW → re-grill r2 (covers data structures, dataflow, and object
  state flow) → `OVERVIEW.md` (+ `has_frontend`/frontend-root, `DATAFLOW.md`,
  confirmed datasource understanding) → planner → `PLAN.md` (Phase 0 always first)
  + skeleton `docs/spec-phase-<n>.md` case-name files. The end-of-`/overview` human
  approval is EXTENDED to confirm the cross-phase skeleton case-name set in the same
  surface (no new gate, §5.51). Also declares the project flags (`project_type`,
  `infra_needed`, `e2e_kind`, `deploy_kind`, `knowledge_docs`).
- **infra** — provision/verify infra (only when `infra_needed: true`): IaC →
  what-if/plan → human review → apply → `INFRA.md` + `.env.test`. Runs the one-time
  AUTH PROOF. Cloud specifics in `knowledge/azure.md`.
- **phase [n]** — run one phase end-to-end with the circuit breaker. Chooses the
  TDD or non-TDD order at RESEARCH. PRE-FLIGHT runs the auth liveness check. TDD
  phases: `spec-author` fills the spec → `spec-staleness.sh` → SPEC REVIEW (human,
  before SCAFFOLD) → SCAFFOLD → RED (generated harness) → `spec-conformance.sh` →
  GREEN → boundary/E2E. Frontend phases run mandatory `ui` boundary with screenshot
  evidence. CLOSE runs the regression guard + ENDPOINTS coverage gate + DATAFLOW
  transition→case coverage gate + evidence-present check.
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

On Claude Code these rituals are AUTOMATED by hook scripts and must NOT be run by
hand. Where a host tool cannot inject context, the model performs them itself.

### SESSION-OPEN (start / clear / compact-resume)

At the start of every session, before any other work, surface:
1. git state (branch, uncommitted count, last 3 commits).
2. `docs/STATE.md` — the current position. READ THIS FIRST.
3. open items in `docs/ISSUES.md`.
4. `docs/research/INDEX.md` (research map) + infra status (when `infra_needed`).
5. shared KB: pull latest + load `docs/.kb-snapshot.md` if `.claude/kb-config.json`
   exists.
6. a one-line reminder of the hard rules below.

### COMPRESS (before a context compaction)

Snapshot the live position to `docs/.snapshots/` so a post-compact session can
recover: current phase, next action, open blocker.

-----

## Hard rules (1–19)

1. Before debugging ANY error: grep `docs/ISSUES.md` AND `docs/research/INDEX.md`.
   The SESSION-OPEN ritual surfaces ISSUES.md — there is no excuse to miss it.
2. Debug attempt cap = 3: WARN the user at attempt 2; the FIRST hard-stop at 3
   STOPS and asks the user. No 4th in-place attempt.
3. Every resolved error -> logged to `docs/ISSUES.md` with root cause + failed
   attempts.
4. End of phase -> synthesize -> context reset -> next phase.
5. **PHASE GATE** = every current-phase spec case's BOUNDARY test passes (`data`:
   real HTTP/CLI/message; `ui` (browser E2E_KIND): Playwright with screenshot evidence) AND the
   accumulated mock regression corpus stays green AND every `docs/ENDPOINTS.md`
   entry has at least one test in `tests/regression/` AND `spec-conformance.sh`
   passed (no TBD, every case-id cited by a boundary test) AND every REACHABLE
   `docs/DATAFLOW.md` transition has at least one filled case in the phase spec
   (rule 14). The final phase additionally runs the full REAL regression corpus and
   requires zero PENDING transitions. A green mock suite alone can never close a phase.
6. On TDD phases the behavioral contract is the human-approved
   `docs/spec-phase-<n>.md`; tests are GENERATED from its case rows (not authored):
   `test-author` emits a deep-equality harness against the shared fixtures for
   `data` cases, `e2e-runner` emits Playwright from the `ui` descriptor (browser
   E2E_KIND). Because the
   spec row and the test load the SAME fixture, a test physically cannot assert
   different values than the locked spec. Humans review the spec (SPEC REVIEW), never
   the tests.
7. Service outage is not a bug — `SERVICE UNAVAILABLE` / `STACK NOT READY` /
   `FLAKE` (plus cloud-specific aliases like `AZURE UNAVAILABLE` per the knowledge
   doc) do not spend the debug budget. Only `LOGIC FAIL` reaches the debugger.
8. E2E auth = a dedicated headless-capable test credential. NEVER script an
   interactive login UI. (Provider specifics — Azure ROPC + MFA-excluded account —
   in `knowledge/azure.md`.)
9. Architectural change (new/removed agent, hook, command, or a changed workflow
   rule)? -> run `log-decision` before closing. A phase that changes an object's
   state lifecycle MUST update `docs/DATAFLOW.md` in the same CLOSE.
10. **Deterministic flags.** `project_type` / `has_frontend` / `infra_needed` /
    `e2e_kind` / `deploy_kind` / `knowledge_docs` are DECLARED at `/overview` and
    recorded in `docs/OVERVIEW.md`; per-phase `TDD_PHASE` + effective `E2E_KIND`
    are bound at RESEARCH and stated. No flag is ever inferred silently mid-phase;
    changing one is a `/replan`-level event.
11. **No-rationalization (scoped).** Do not, in order to dodge a gate:
    downgrade a TDD phase to non-TDD or route phase-worthy work through `quick`
    (RED gate); set `has_frontend: false` or keep a touched element out of the
    acceptance spec (E2E / UI-existence gate); fabricate a fixture value or leave a
    `TBD` to slip past SPEC REVIEW / conformance instead of escalating UNDERSPEC or
    `CASE-SET-DIVERGENCE`; mark a reachable transition PENDING (DATAFLOW gate); or
    skip evidence capture. (Scoped deliberately to these named seams; this is not a
    broad "never make excuses" rule.)
12. **SPEC REVIEW (TDD phases).** SCAFFOLD cannot begin until the human confirms the
    filled `docs/spec-phase-<n>.md` cases, surfaced as falsifiable claims. Rejection
    is classified at the gate (§5.50): wrong expected → fix case row + fixture; wrong
    input shape → re-dispatch `spec-author`; new or contradicted case → hard re-entry
    to amend the up-front case-name contract, re-confirm the amended + same-`covers`
    neighbor cases (staleness-hash certifies the unchanged remainder), then re-fill
    (§5.52). Unskippable on TDD phases; absent on the non-TDD path (no behavioral
    contract to review). Replaces the v2.1 human TEST REVIEW gate (removed — humans
    no longer review tests).
13. **Mandatory boundary run + evidence (per E2E_KIND).** Browser: when
    `has_frontend: true` and the phase's `changes` touch the frontend root recorded
    in OVERVIEW.md, E2E MUST run; each UI-existence assertion captures a screenshot
    (on success too) to `docs/evidence/e2e-phase-<n>/`. Other kinds
    (cli/http/library-api): the phase's boundary tests MUST run in real mode against
    the outer surface with output captured to the same evidence dir. Boundary-relevant
    files changed with no boundary run, or a closed phase with no evidence on disk,
    fails CLOSE hard. (Evidence is gitignored — present-on-disk at CLOSE is the check,
    not committed history.)
14. **DATAFLOW transition coverage (re-seamed v2.2, §5.56).** Every transition in
    `docs/DATAFLOW.md` whose trigger is reachable in the code shipped so far MUST
    have ≥1 FILLED CASE in `docs/spec-phase-<n>.md` (was: ≥1 test in
    `tests/regression/`); zero coverage on a reachable transition fails CLOSE hard.
    Unreachable transitions list as PENDING. Any transition still PENDING at the
    final phase fails hard. The case→test half of the old guarantee now lives in
    `spec-conformance.sh` (rule 18: every case-id is cited by a boundary test, which
    by placement convention lands in `tests/regression/`). Peer to the ENDPOINTS
    coverage gate, which is unchanged and orthogonal (endpoint-keyed, not
    behavior-keyed).
15. **Datasource data understanding.** Real-suite / E2E tests against an external
    datasource are HARD-BLOCKED until that datasource's DATA UNDERSTANDING is
    confirmed (baseline at `/overview`; per-phase delta-confirm for any
    new table/column). The mock suite still runs. No testing against data you
    never confirmed understanding of.
16. **Auth proof + liveness.** A one-time AUTH PROOF at `/infra` (when
    `infra_needed`) proves every credential the real tests use — the app login AND
    every external datasource credential — is obtainable headlessly twice in a row
    (prime + reuse) with zero prompts; "reusable without interaction" means exactly
    this. Each `/phase` PRE-FLIGHT runs a cheap liveness check (the command recorded
    in `docs/INFRA.md ## AUTH`) before dispatching real/E2E. Both fail loud; the
    mock suite proceeds regardless.
17. **Spec staleness (§5.55).** `scripts/spec-staleness.sh <n>` runs immediately
    after `spec-author` fills the spec AND again at SPEC REVIEW entry. It re-hashes
    the current `PLAN.md` `acceptance:` line + the in-scope `DATAFLOW.md` transition
    rows and compares to the hash embedded in the spec's generated header. A
    mismatch (upstream drifted since the skeleton was generated) exits nonzero and
    blocks SPEC REVIEW — the spec must be regenerated/re-filled. The generated
    header is never hand-edited.
18. **Spec conformance (§5.55).** `scripts/spec-conformance.sh <n>` runs between RED
    and GREEN, replacing the removed human TEST REVIEW gate. It loud-fails (blocks
    GREEN) if any `TBD` marker remains in the spec or its fixtures, or if any case-id
    in the spec table has no boundary test citing it via the `# spec: <case-id>`
    convention.
19. **Author ≠ implementer (§5.53).** `spec-author` and `implementer` are distinct
    roles. `spec-author` fills the spec + fixtures and NEVER reads implementation
    logic; `implementer` reads the filled spec as its contract and NEVER authors spec
    fixtures. `test-author` / `e2e-runner` are harness EMITTERS, not assertion
    authors. This replaces the v2.1 test-author RED-first blindness invariant: spec
    fixtures are written before code, so the contract cannot be shaped toward an
    implementation.

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
- `docs/PLAN.md` — the phase plan. Phase 0 (infra) first iff `infra_needed`; last
  phase completes `deploy_kind`.
- `docs/HISTORY.md` — one line per finished phase.
- `docs/DESIGN_LOG.md` — kit architectural rationale (§5.x decision log).
- `docs/OVERVIEW.md` — project scope. Written after the double-grill in `overview`.
  Carries the project flags (`project_type`, `has_frontend` + frontend root,
  `infra_needed`, `e2e_kind`, `deploy_kind`, `knowledge_docs`) and the
  data/state-flow summary.
- `knowledge/<usecase>.md` — preinstalled matured practice (`webapp.md`,
  `azure.md`), consulted by `researcher` when listed in OVERVIEW `knowledge_docs`.
  Ships use-case templates materialized per project on demand.
- `.claude/ref/compression.md` — kit-native compression profiles (`user`,
  `internal`), single source, always-on. Not a skill.
- `docs/DATAFLOW.md` — state-transition table per key object (`object | states |
  transition (from→to) | trigger | who writes | external system`). Living doc,
  grill-driven; drives the CLOSE transition-coverage gate. The data-side analogue
  of `ENDPOINTS.md`. (v2.1)
- `docs/spec-phase-<n>.md` — the per-phase behavioral contract (v2.2). Skeleton
  (case names + `TBD` values) generated at `/overview`; filled by `spec-author` per
  phase. Generated self-correlating header transcludes the phase's `PLAN.md`
  `acceptance:` line + in-scope `DATAFLOW.md` transition rows and embeds a staleness
  hash (never hand-edited). The only human-authored region is the example-case table.
  Human-approved at SPEC REVIEW before SCAFFOLD. (Committed.)
- `fixtures/<case-id>-input.json` / `-expected.json` / `-ui.json` — the shared
  fixtures a spec row references AND the generated test harness loads (transcription
  is structural, not honor-system). `-expected.json` carries matcher tokens for
  volatile fields; `-ui.json` is the `[{selector,assert,value}]` UI descriptor.
  (Committed — part of the contract.) (v2.2)
- `tests/helpers/spec-assert.*` — the kit-versioned per-language comparator that
  honors matcher tokens (`<UUID>`, `<ISO8601>`, `<ANY_STRING>`, `<ANY_NUMBER>`,
  `<UNORDERED>`, `<MATCHES:regex>`). One implementation per supported test language;
  NO per-project comparator code. (v2.2)
- `docs/evidence/e2e-phase-<n>/` — screenshot evidence captured at each UI-existence
  assertion (gitignored; present-on-disk at CLOSE is the gate). (v2.1)
- `docs/INFRA.md` — infra manifest (when `infra_needed`): resource IDs, endpoints,
  cost estimates, E2E target, `## AUTH` liveness command, AUTH PROOF result.
- `docs/ENDPOINTS.md` — API/service endpoint catalogue. Maintained by implementer
  each phase. Drives the CLOSE coverage gate.
- `docs/research/` — full research + debug files. `INDEX.md` is the searchable map.
  `design-<slug>.md` (design research), `<slug>.md` (impl research),
  `debug-<slug>.md` (debugger traces), `datasource-<name>.md` (confirmed data
  understanding, referenced from DATAFLOW.md external rows).
- `docs/.snapshots/` — pre-compact recovery markers (auto-pruned, gitignored).
- `infra/` — IaC templates, generated per project by `infra-provisioner`. Committed
  (audit trail). `infra/params.json` holds no secrets. (Azure Bicep specifics:
  `knowledge/azure.md`.)
- `knowledge/webapp.md` owns the browser E2E stack templates (`playwright.config.ts`,
  `e2e/global-setup.ts`, `docker-compose.test.yml`, `scripts/e2e-stack.sh`) —
  materialized into the project only when a browser phase needs them, then user-owned.
- `tests/phase-<n>/` — phase-local test suites.
- `tests/regression/` — cross-phase contract tests (the regression corpus). Run by
  `scripts/regression.sh` (default mock; `--real` runs the real corpus).
- `scripts/spec-staleness.sh <n>` — loud-fails if the spec's generated header drifted
  from the current `PLAN.md` acceptance line + `DATAFLOW.md` rows (rule 17). (v2.2)
- `scripts/spec-conformance.sh <n>` — loud-fails on any remaining `TBD` or any
  case-id with no citing boundary test (rule 18). Runs between RED and GREEN. (v2.2)
- `.claude/kb-config.json` — shared KB path + remote (optional, written by setup.sh).
- `docs/.kb-snapshot.md` — KB INDEX loaded this session (auto-generated, gitignored).

-----

## Capability matrix (which tools get what)

- **Claude Code — full (the only supported target, v2.3).** Generated commands
  (`.claude/commands/`); all three lifecycle hooks WITH context injection
  (SessionStart / PreCompact / SubagentStop); named subagents (`.claude/agents/*.md`);
  `@AGENTS.md` import; shared KB.
- **Everything else.** Reads this `AGENTS.md` if it supports the open standard.
  No generated adapters, no support claim (Cursor parity was dropped in v2.3, §5.69).
