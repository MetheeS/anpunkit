# anpunkit — AI-coding system development workflow

A reusable, self-navigating workflow for **Claude Code**. Install with one `npx`
command, or clone it directly into your project.

## Why

Codifies a `design-research -> grill -> plan -> implement -> test -> deploy` loop
with vertical-slice phases, blind testing, agent orchestration, and automatic
context hygiene — so the workflow runs itself instead of being hand-steered every
session. The invariant core (loop, gates, doc system, commands) is use-case
agnostic; web/Azure practice ships as **preinstalled knowledge docs**
(`knowledge/webapp.md`, `knowledge/azure.md`) that the researcher consults only
when your declared project type calls for them. Works for web apps, desktop apps,
scripts, and libraries alike.

## The core idea

Mandatory steps live in **hooks** (deterministic, cannot be skipped).
Thinking steps live in **subagents + skills** (the model reasons).
Putting "read the issue log" in a hook is why it stops getting skipped.

## Install

**End users — `npx` (recommended):**
```bash
cd my-project
npx create-anpunkit            # non-destructive: never clobbers your files
# then open Claude Code — the session-start hook fires automatically
/overview                      # bootstrap the project (declares project type + flags)
```
Useful flags: `--dry-run` (print the plan, write nothing), `--force` (overwrite
user-modified kit files), `--kb-path <dir>` (your pre-cloned KB repo; remote
auto-recorded from its origin) / `--no-kb`.

Upgrading an existing anpunkit project? Re-run `npx create-anpunkit`. It refreshes
kit-owned files, preserves anything you modified as `<file>.anpunkit-new`, merges
hook config into your existing `.claude/settings.json`, and writes a timestamped
`.anpunkit-backup-*/` first.

> **Upgrading from v2.2 (Cursor dropped):** v2.3 is Claude Code only. After
> upgrading you may safely delete the now-orphaned `.cursor/`,
> `.claude/hooks/cursor-session-start.sh`, and `.claude/anpunkit-tools.json` —
> setup.sh no longer manages them.

**Kit developers — clone + `setup.sh`:**
```bash
git clone https://github.com/MetheeS/anpunkit.git my-project
cd my-project && bash setup.sh
```

> `npx create-anpunkit` requires Node >= 18 and `bash` on PATH (Git Bash on
> Windows). Claude Code already requires Node, so this adds no new dependency.

## Commands

|Command          |Does                                                                          |
|-----------------|------------------------------------------------------------------------------|
|`/overview`      |design-research → RESEARCH REVIEW → grill (×2, incl. data/state flow) → OVERVIEW (+ project flags) + DATAFLOW → PLAN → STATE|
|`/infra`         |provision infra (when `infra_needed`): IaC → what-if → review → apply → INFRA.md + .env.test → AUTH PROOF|
|`/phase [n]`     |run one phase: research → SPEC fill → SPEC REVIEW → SCAFFOLD → RED → conformance → GREEN → boundary/E2E, with circuit breaker|
|`/quick [change]`|small obvious change, direct, no agent chain                                  |
|`/unstuck`       |deep re-research after a circuit breaker (you trigger it)                     |
|`/synthesize`    |compress STATE.md, dedup ISSUES.md, prune snapshots                           |
|`/replan`        |revise PLAN.md when it drifts (reconciles regression corpus + DATAFLOW)        |
|`/log-issue`     |append an error with root cause + failed attempts                             |
|`/log-decision`  |record an architectural change in DESIGN_LOG.md                               |
|`/store-wisdom`  |promote resolved issues + research findings to shared KB                      |

## Subagents

`researcher` (Haiku, two modes: design + impl) · `planner` (Opus, also writes skeleton specs) ·
`infra-provisioner` (Opus) · `spec-author` (Opus, fills per-phase spec + fixtures) ·
`implementer` (Opus, SCAFFOLD/FILL modes) · `test-author` (Opus, harness emitter) · `debugger` (Opus, isolated) ·
`e2e-runner` (Opus, Playwright emitter) · `synthesizer` (Haiku)

The main session is the orchestrator — it routes, it does not implement.

## The loop (v2.3: adaptive to project type + spec-driven contract + upstream human gate)

**Project flags (declared at `/overview`).** The grill asks your `project_type`
(web app / desktop app / script / library / other) and what "shipped" means. From
that it derives `infra_needed`, `e2e_kind` (browser / cli / http / library-api),
`deploy_kind` (cloud-deploy / package-publish / install-run-verified / none), and
which `knowledge_docs` to consult — all recorded in `docs/OVERVIEW.md`, never
inferred mid-phase. Phase 0 (infra) exists only when `infra_needed`; the boundary
run is selected by `e2e_kind`; the final phase completes `deploy_kind`.


Phases that add a public callable surface run spec-first:
`RESEARCH -> SPEC fill -> spec-staleness -> SPEC REVIEW -> SCAFFOLD -> RED -> spec-conformance -> GREEN -> boundary/E2E -> FIX -> CLOSE`.
The reviewable, authoritative artifact is the **spec**, not the test. At `/overview`
the planner enumerates the case *names* per phase (skeleton `docs/spec-phase-<n>.md`).
At phase start the new `spec-author` fills them with concrete cases — real inputs,
real expected outputs, matcher tokens for volatile fields — written to shared
`fixtures/` files. **SPEC REVIEW** is a human gate that sits *upstream* (before any
code): you confirm falsifiable claims in plain language ("empty order → 422
EMPTY_ORDER"). Tests are then GENERATED from the locked spec rows (deep-equality +
matcher tokens for `data`; Playwright from the descriptor for `ui`) loading the
*same* fixtures — so a test physically cannot assert different values than the spec.
`spec-conformance.sh` blocks GREEN until no `TBD` remains and every case-id is cited
by a boundary test. This is the v2.2 fix for "both agents independently fabricated
the same wrong contract from a one-line acceptance and the suite went green on a
broken core." Pure infra/config/doc phases keep the direct
`RESEARCH -> IMPLEMENT -> TEST` order (no spec, no SPEC REVIEW — no public surface).

Frontend phases are detected by a **deterministic path match** (`has_frontend` +
the frontend root, both set in `docs/OVERVIEW.md`): if a phase changes a file
under the frontend root, **E2E is mandatory**, the acceptance spec must name the
specific user-visible element it introduces (not "page renders 200"), and the
`e2e-runner` captures a screenshot at each such assertion — on success too — to a
gitignored `docs/evidence/` dir. That's the fix for shipping a missing sign-in button.

Every phase CLOSE runs the accumulated **mock regression corpus**
(`tests/regression/`, via `scripts/regression.sh`) plus a hard ENDPOINTS coverage
gate AND a **DATAFLOW transition-coverage gate** — every reachable state
transition in `docs/DATAFLOW.md` (the data-side analogue of `ENDPOINTS.md`,
grilled out at `/overview`) must have a regression test. The final phase
additionally runs the full real corpus and allows zero PENDING transitions.

External datasources get a confirmed, falsifiable **DATA UNDERSTANDING** (grain,
fields, sample shape, meaning-breaking assumption) before real tests run, and auth
is proven reusable once at `/infra` (obtainable headlessly twice in a row) with a
cheap liveness check each phase.

Methodology lives in one place: the portable **`AGENTS.md`** at the repo root.
`CLAUDE.md` is a thin `@AGENTS.md` shim with Claude-native wiring only.

## Compatibility

|Tool          |What you get                                                                                          |
|--------------|------------------------------------------------------------------------------------------------------|
|**Claude Code** (the supported target)|commands, all 3 lifecycle hooks **with context injection**, named subagents, shared KB, `@AGENTS.md` import|
|**Other tools**|read `AGENTS.md` if they support the open standard; no generated adapters, no support claim|

The canonical command bodies live in `commands.src/<name>.md`, copied to
`.claude/commands/` at install. **Cursor support was dropped in v2.3** (§5.69) —
the maintenance cost exceeded demand. v2.3 is Claude Code only.

## Compression

Output compression is a kit-native, always-on facility (`.claude/ref/compression.md`),
not a skill and never model-invoked. Two profiles: `user` (human-facing, keeps the
Auto-Clarity exception for security warnings, irreversible-action confirmations,
multi-step sequences, and clarification requests) and `internal` (agent↔agent,
harder). `AGENTS.md` declares `user`; every subagent prompt points at `internal`.
Exact-output artifacts (fixtures, spec rows, generated tests) are exempted by
structural gates in the emitter prompts.

## How each problem is solved

|Your problem                               |Fix in this kit                                                                              |
|-------------------------------------------|---------------------------------------------------------------------------------------------|
|Agents miss the issue log                  |SessionStart hook injects open ISSUES.md every session — not optional                        |
|Manual navigation every session            |SessionStart hook injects STATE.md + git + active phase                                      |
|Stuck on a bug too long                    |warn at attempt 2; first hard-stop at 3 STOPS and asks you; `/unstuck` for deep re-research  |
|Context rot during debugging               |`researcher` + `debugger` write full output to `docs/research/`, return only a summary + path|
|Want orchestration                         |8 scoped subagents; `/phase` is the orchestrator routing them                                |
|Handoff / memory keeps growing             |`synthesizer` + PreCompact hook compress and dedup                                           |
|Cloud auth friction per session            |liveness ritual recorded in INFRA.md `## AUTH` (Azure: `knowledge/azure.md`) — one check per session|
|Infra created ad-hoc mid-phase             |`infra-provisioner` + Phase 0 when `infra_needed` — provisioned once, reviewed before apply  |
|Planning without domain knowledge          |design-researcher runs before planning; consults matching `knowledge/*.md`; double grill absorbs findings|
|Deployment not in the plan                 |planner always puts the `deploy_kind` completion task in the last phase                      |
|No endpoint summary at project end         |final-phase close shows usage endpoints from docs/ENDPOINTS.md                               |
|Re-discovering same gotchas across projects|`/store-wisdom` promotes findings to shared KB; researcher checks KB before web              |

## Files it manages

- `docs/STATE.md` — current position, kept small (rewritten each phase)
- `docs/ISSUES.md` — error log, deduped by synthesizer
- `docs/PLAN.md` — vertical-slice phase plan (Phase 0 first when `infra_needed`)
- `docs/HISTORY.md` — one line per finished phase
- `docs/OVERVIEW.md` — project scope, written after double-grill
- `docs/DATAFLOW.md` — state-transition table per key object (grilled at /overview; drives CLOSE coverage gate)
- `docs/spec-phase-<n>.md` — per-phase behavioral contract (skeleton at /overview, filled by spec-author; human-reviewed at SPEC REVIEW)
- `fixtures/<case-id>-{input,expected,ui}.json` — shared by the spec row and the generated test harness (committed; part of the contract)
- `tests/helpers/spec-assert.{py,ts}` — kit-versioned matcher-aware comparator (honors `<UUID>`, `<ISO8601>`, … tokens)
- `docs/INFRA.md` — infra resource manifest + cost estimates (when `infra_needed`; written by infra-provisioner)
- `docs/ENDPOINTS.md` — API/service endpoint catalogue (maintained by implementer)
- `docs/.snapshots/` — pre-compact recovery markers (auto-pruned, gitignored)
- `knowledge/webapp.md`, `knowledge/azure.md` — preinstalled matured practice + materializable templates
- `.claude/ref/compression.md` — kit-native compression profiles (`user`, `internal`)
- `infra/` — IaC templates (generated by infra-provisioner, committed to git)

## Shared Knowledge Base (optional)

The kit can connect to a shared GitHub repo (`anpunkit-kb`) that accumulates
resolved issues and research findings across all your projects. Once configured,
the researcher checks the KB at the start of every session — so you stop
re-discovering the same Azure/Databricks gotchas project after project.

**Setup (one-time per machine):**

```bash
# 1. Create a GitHub repo: anpunkit-kb (empty is fine)
# 2. Clone it yourself, somewhere permanent — you own the git auth
git clone git@github.com:<you>/anpunkit-kb.git ~/anpunkit-kb

# 3. Point anpunkit at it
npx create-anpunkit --kb-path ~/anpunkit-kb
# (or paste the path at the interactive prompt)
```

That's the last manual git you'll run against the KB. From then on the
**session-start hook pulls** each session and **`/store-wisdom` commits and
pushes** (always with your approval). The remote URL is recorded automatically
from the clone's `origin`; `--kb-remote <url>` overrides it if needed.

**Usage:**

```
/store-wisdom    # after a resolved bug or completed phase — promotes findings to KB
```

See `docs/KB_GUIDE.md` in the anpunkit-kb repo (created by first `/store-wisdom` run).

## Daily flow

```
/overview                    once per project (design-research + double grill)
/infra                       once per project (Phase 0) — only when infra_needed
<INFRA.md AUTH command>      once per session (infra projects; Azure: scripts/auth-setup.sh)
/phase 1   ->  /synthesize  ->  /clear
/phase 2   ->  /synthesize  ->  /clear
...
# last phase -> shows usage endpoints automatically
# bug won't die?  ->  /unstuck
# plan drifted?   ->  /replan
# learned something worth keeping?  ->  /store-wisdom
```

## Use-case knowledge (infra, E2E, deploy)

The invariant core ships nothing use-case specific. Matured web/Azure practice
lives in **preinstalled knowledge docs** that the `researcher` consults at RESEARCH
when your declared `project_type` matches (recorded in OVERVIEW `knowledge_docs`):

- **`knowledge/webapp.md`** — browser E2E practice (Playwright, closed assert
  vocabulary, screenshot evidence) plus the E2E stack ritual and the
  `playwright.config.ts` / `e2e/global-setup.ts` / `docker-compose.test.yml` /
  `scripts/e2e-stack.sh` templates, materialized into your project on demand.
- **`knowledge/azure.md`** — the once-per-session auth ritual (`scripts/auth-setup.sh`
  template), Entra/MSAL ROPC + MFA-excluded test account practice, and the Bicep /
  `az` provisioning patterns (Key Vault, THB cost annotations, SEA region default).

### Infra (Phase 0, when `infra_needed`)

Application project types (web app, desktop app, service) set `infra_needed: true`;
scripts and libraries set it false and skip Phase 0 entirely. When present, Phase 0
is provisioned once before any code phase, owned by `infra-provisioner`:

```
/overview          # declares infra_needed; includes Phase 0 in PLAN.md when true
/infra             # generates IaC -> what-if diff -> you review -> "go" -> apply
                   # writes docs/INFRA.md (resource manifest + cost estimates + ## AUTH)
                   # writes .env.test (generated, never fill manually)
                   # runs AUTH PROOF (every credential proven reusable headlessly)
/phase 1           # PRE-FLIGHT checks Phase 0 is done before starting
```

Cloud specifics (Azure `az`/Bicep commands, region/cost conventions, the session
auth ritual) live in `knowledge/azure.md`, consulted by `infra-provisioner`.

### Boundary testing (per `e2e_kind`)

The boundary run is selected by the phase's bound `e2e_kind`:

- **browser** (frontend phases): `e2e-runner` emits Playwright from each `ui` case's
  descriptor and captures a screenshot at every UI-existence assertion — on success
  too — to a gitignored `docs/evidence/` dir. Stack ritual + templates:
  `knowledge/webapp.md`.
- **cli / http / library-api**: the phase's real-mode boundary suite runs against
  the shipped outer surface, transcript captured as evidence.

Mock-green alone never closes a phase.

## Windows / Git Bash

The hooks are bash scripts. On Windows they run under **Git Bash**.

- **Line endings.** The shipped `.gitattributes` pins all `.sh` files to LF.
- **`bash` on PATH.** Verify in PowerShell: `bash --version`.

Hook commands use a BARE `bash` prefix: `bash .claude/hooks/session-start.sh`.
Never an explicit bash.exe path — that triggers a Claude Code argument-splitter bug.

**Verifying hooks:** in a fresh session ask Claude:

> What does my STATE.md say, and how many open issues are in ISSUES.md?

A correct answer without reading any file = hooks working. No visible banner on
newer Claude Code versions is normal — injection may be silent.

(WSL users: the kit runs as-is — WSL is Linux.)
