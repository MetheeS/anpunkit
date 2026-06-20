# anpunkit — AI-coding system development workflow

A reusable, self-navigating workflow for **Claude Code and Cursor**. Install with
one `npx` command, or clone it directly into your project.

## Why

Codifies a `design-research -> grill -> plan -> implement -> test -> deploy` loop
with vertical-slice phases, blind testing, agent orchestration, automatic context
hygiene, and Azure infrastructure as a first-class Phase 0 — so the workflow runs
itself instead of being hand-steered every session.

## The core idea

Mandatory steps live in **hooks** (deterministic, cannot be skipped).
Thinking steps live in **subagents + skills** (the model reasons).
Putting "read the issue log" in a hook is why it stops getting skipped.

## Install

**End users — `npx` (recommended):**
```bash
cd my-project
npx create-anpunkit            # non-destructive: never clobbers your files
# then open Claude Code or Cursor — the session-start hook fires automatically
/overview                      # bootstrap the project (includes Phase 0 infra)
```
Useful flags: `--dry-run` (print the per-tool plan, write nothing), `--force`
(overwrite user-modified kit files), `--tools <claude,cursor>` (install only the
selected tools' files; interactive menu if omitted on a fresh TTY install),
`--add-tool <name>` (lay down an additional tool's files into an existing
project), `--kb-path <dir>` (your pre-cloned KB repo; remote auto-recorded from
its origin) / `--no-kb`.

Upgrading an existing anpunkit project? Re-run `npx create-anpunkit`. It refreshes
kit-owned files, preserves anything you modified as `<file>.anpunkit-new`, merges
hook config into your existing `settings.json` / `.cursor/hooks.json`, and writes a
timestamped `.anpunkit-backup-*/` first.

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
|`/overview`      |design-research → RESEARCH REVIEW → grill (×2, incl. data/state flow) → OVERVIEW + DATAFLOW → PLAN (Phase 0 first) → STATE|
|`/infra`         |provision Azure infra: Bicep → what-if → review → apply → INFRA.md + .env.test → AUTH PROOF|
|`/phase [n]`     |run one phase: research → SCAFFOLD → RED → TEST REVIEW → GREEN → E2E, with circuit breaker|
|`/quick [change]`|small obvious change, direct, no agent chain                                  |
|`/unstuck`       |deep re-research after a circuit breaker (you trigger it)                     |
|`/synthesize`    |compress STATE.md, dedup ISSUES.md, prune snapshots                           |
|`/replan`        |revise PLAN.md when it drifts (reconciles regression corpus + DATAFLOW)        |
|`/log-issue`     |append an error with root cause + failed attempts                             |
|`/log-decision`  |record an architectural change in DESIGN_LOG.md                               |
|`/store-wisdom`  |promote resolved issues + research findings to shared KB                      |

## Subagents

`researcher` (Haiku, two modes: design + impl) · `planner` (Opus) · `infra-provisioner` (Opus) ·
`implementer` (Opus, SCAFFOLD/FILL modes) · `test-author` (Opus, blind, RED-first) · `debugger` (Opus, isolated) ·
`e2e-runner` (Opus, blind, Playwright) · `synthesizer` (Haiku)

The main session is the orchestrator — it routes, it does not implement.

## The loop (v2.1: TDD-first + human gates + coverage guards)

Phases that add a public callable surface run test-first:
`RESEARCH -> SCAFFOLD -> RED -> TEST REVIEW -> GREEN -> E2E -> FIX -> CLOSE`. The
implementer writes interface stubs only; the `test-author` writes the suite blind
against those stubs (it must collect cleanly and FAIL — the RED gate) and emits a
`docs/test-plan-phase-<n>.md` with a mandatory "NOT covered / assumptions"
section. **TEST REVIEW** is a human gate: you approve the test plan before the
implementer fills to green — so "all tests passed but the core was broken" can't
slip through silently. Pure infra/config/doc phases keep the direct
`RESEARCH -> IMPLEMENT -> TEST` order (no TEST REVIEW — no public surface).

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
|**Claude Code** (full, reference)|commands, all 3 lifecycle hooks **with context injection**, named subagents, shared KB, `@AGENTS.md` import|
|**Cursor** (full)|generated commands (`.cursor/commands/`), lifecycle hooks (`.cursor/hooks.json`: sessionStart / preCompact / subagentStop), methodology via a `.cursor/rules/` pointer to `AGENTS.md`|
|**Other tools**|read `AGENTS.md` if they support the open standard; no generated adapters; not claimed as supported in v2.0|

One canonical command body in `commands.src/<name>.md` generates both tools' command sets at install.

**Cursor — verified against cursor.com/docs (June 2026):**
- **sessionStart context injection: works.** Cursor's `sessionStart` hook accepts an
  `additional_context` JSON output field injected into the conversation's initial
  context. Cursor expects JSON (Claude injects raw stdout), so the shipped wiring
  runs the shared body through `cursor-session-start.sh`, a thin JSON-envelope
  wrapper. The hook is fire-and-forget (non-blocking).
- **Named subagents: work natively.** Cursor reads `.claude/agents/*.md` directly
  (documented Claude-compatibility path), with `/name` invocation and
  description-based delegation — one set of role files serves both tools.
  Caveat: `model: haiku/opus` tiers are Claude-specific; Cursor falls back to
  `inherit`/a compatible model.
- **Hook path resolution: project hooks run from the project root** (not
  `.cursor/`), so the shipped wiring uses `bash .claude/hooks/<script>.sh`. Cursor
  sets `CLAUDE_PROJECT_DIR` as a compatibility alias, so the shared scripts run
  unchanged.
- **preCompact is observational** in Cursor (cannot modify compaction); the
  snapshot side-effect still runs, which is all the COMPRESS ritual needs.

> Note: Cursor can also load `.claude/settings.json` hooks directly ("Third-party
> skills" toggle). anpunkit does not rely on this — it requires a manual settings
> toggle (silent no-op if forgotten) and would double-fire hooks alongside
> `.cursor/hooks.json`. The explicit native wiring is the supported path.

Codex is **not** a target in v2.0 (its repo-committed command path is deprecated
home-dir custom-prompts with a divergent UX).

## How each problem is solved

|Your problem                               |Fix in this kit                                                                              |
|-------------------------------------------|---------------------------------------------------------------------------------------------|
|Agents miss the issue log                  |SessionStart hook injects open ISSUES.md every session — not optional                        |
|Manual navigation every session            |SessionStart hook injects STATE.md + git + active phase                                      |
|Stuck on a bug too long                    |warn at attempt 2; first hard-stop at 3 STOPS and asks you; `/unstuck` for deep re-research  |
|Context rot during debugging               |`researcher` + `debugger` write full output to `docs/research/`, return only a summary + path|
|Want orchestration                         |8 scoped subagents; `/phase` is the orchestrator routing them                                |
|Handoff / memory keeps growing             |`synthesizer` + PreCompact hook compress and dedup                                           |
|Azure auth friction per session            |`scripts/auth-setup.sh` — one token check, once per session                                  |
|Infra created ad-hoc mid-phase             |`infra-provisioner` + Phase 0 — provisioned once, reviewed before apply                      |
|Planning without domain knowledge          |design-researcher runs before planning; double grill absorbs findings                        |
|Deployment not in the plan                 |planner always puts deploy task in last phase                                                |
|No endpoint summary at project end         |final-phase close shows usage endpoints from docs/ENDPOINTS.md                               |
|Re-discovering same gotchas across projects|`/store-wisdom` promotes findings to shared KB; researcher checks KB before web              |

## Files it manages

- `docs/STATE.md` — current position, kept small (rewritten each phase)
- `docs/ISSUES.md` — error log, deduped by synthesizer
- `docs/PLAN.md` — vertical-slice phase plan (Phase 0 always first)
- `docs/HISTORY.md` — one line per finished phase
- `docs/OVERVIEW.md` — project scope, written after double-grill
- `docs/DATAFLOW.md` — state-transition table per key object (grilled at /overview; drives CLOSE coverage gate)
- `docs/INFRA.md` — Azure resource manifest + cost estimates (written by infra-provisioner)
- `docs/ENDPOINTS.md` — API/service endpoint catalogue (maintained by implementer)
- `docs/.snapshots/` — pre-compact recovery markers (auto-pruned, gitignored)
- `infra/` — Bicep templates (generated by infra-provisioner, committed to git)

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
/infra                       once per project (Phase 0) — after /overview
scripts/auth-setup.sh        once per session (Azure projects)
/phase 1   ->  /synthesize  ->  /clear
/phase 2   ->  /synthesize  ->  /clear
...
# last phase -> shows usage endpoints automatically
# bug won't die?  ->  /unstuck
# plan drifted?   ->  /replan
# learned something worth keeping?  ->  /store-wisdom
```

## Azure infrastructure (Phase 0)

The kit treats Azure infra as **Phase 0** — provisioned once before any code
phase starts, owned by the `infra-provisioner` subagent.

### Phase 0 flow

```
/overview          # includes Phase 0 in PLAN.md automatically
/infra             # generates Bicep -> what-if diff -> you review -> "go" -> apply
                   # writes docs/INFRA.md (resource manifest + cost estimates)
                   # writes .env.test (generated, never fill manually)
                   # runs AUTH PROOF (every credential proven reusable headlessly)
/phase 1           # PRE-FLIGHT checks Phase 0 is done before starting
```

### Session startup (Azure projects)

Run once per session before any Azure work:

```bash
scripts/auth-setup.sh
```

Checks your `az` token is fresh and the right subscription is active.
Prompts `az login` only if stale. No credential storage — your account only.

### What /infra does

1. `infra-provisioner` reads `docs/OVERVIEW.md` for the system design
1. Generates `infra/main.bicep` + per-service modules under `infra/modules/`
1. Runs `az deployment what-if` — shows exactly what will be created
1. **Stops and waits for your "go"** — nothing applied without your review
1. Applies the deployment
1. Writes `docs/INFRA.md` — resource IDs, endpoints, cost estimates (THB, SEA region)
1. Generates `.env.test` from the manifest
1. Runs the **AUTH PROOF** — proves every credential (Entra/MSAL + datasources) is obtainable headlessly twice in a row

Re-run `/infra` any time infra drifts or a new resource is needed.
Re-run `/infra regenerate-env` to refresh `.env.test` only.
Re-run `/infra auth-proof` to re-prove credentials on demand.

### Cost awareness

`infra-provisioner` annotates every resource in `INFRA.md` with an estimated
monthly cost. It uses production-appropriate SKUs by default — not artificially
cheap dev tiers that need resizing before go-live.

### E2E target

`infra-provisioner` determines the E2E target from the system design:

- **azure-deployed**: `E2E_STACK_EXTERNAL=1` — Playwright hits your deployed Azure app.
- **local-docker**: Containers run the app, pointed at real Azure services.

### Test data

Seeding and cleanup are **deployment phase** concerns, not E2E concerns.
`e2e-stack.sh` has no seed/cleanup commands.

## End-to-end testing

Three layers: unit/integration (mock suite), real API (`test-author`), and
functional browser E2E (`e2e-runner`, Playwright).

**Phase gate:** a frontend-touching phase closes only when the real API suite
AND the browser E2E suite pass with screenshot evidence. Mock-green alone never closes a phase.

**MSAL / Entra ID auth.** Browser E2E never drives the Microsoft login UI.
`e2e/global-setup.ts` uses ROPC flow with a dedicated test account (MFA excluded
via Conditional Access) to fetch a real token and inject it into the MSAL cache.

**E2E setup (one-time per project):**

1. Run `/infra` — it generates `.env.test` automatically and runs the AUTH PROOF.
1. Provision the Entra test user + Conditional Access MFA exclusion.
1. `npm i -D @playwright/test && npx playwright install chromium`

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
