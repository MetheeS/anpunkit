# anpunkit — Design Log

> **What this file is.** The design rationale for the anpunkit: not just *what*
> was built but *why*, including rejected alternatives — so a future change
> does not re-break a problem an earlier decision already solved. Read it first
> in any session where you intend to extend or change the kit.
>
> **This is a living document.** Updated ONLY when the kit's *architecture*
> changes. Run `/log-decision` to update — never silently rewrite history.
>
> **What it is NOT.** Not STATE.md (volatile handoff). Not HISTORY.md (project
> journal). This file is architectural and stable; those are operational.

---

## 0. Changelog

Newest first. One entry per architectural change. Appended by `/log-decision`.

- **(v2.0.2)** — KB setup stays PATH-FIRST: the user clones the KB repo
  themselves (`git clone ... ~/anpunkit-kb`) and passes `--kb-path` (or the
  interactive prompt). New: the remote URL is auto-recorded from the clone's
  `origin`, so `--kb-remote` is optional metadata. After setup, no manual git:
  the session-start hook pulls; `/store-wisdom` commits and pushes (human-gated).
  REJECTED: URL-first setup where anpunkit runs `git clone` itself — it was built
  and tested, then dropped: it entangles a fresh install with the user's GitHub
  authentication (SSH keys / gh auth), and a clone failure mid-setup is a worse
  failure mode than asking a developer to run one clone command they already
  understand. Setup records state; it does not acquire credentials.

- **(v2.0.1)** — Windows portability fix for the npx installer. (1) `cli.js` no
  longer trusts bare `bash` on win32: PowerShell resolves it to the System32 WSL
  relay, which fails with `execvpe(/bin/bash)` when no distro is installed. The
  bin now locates Git Bash explicitly (ANPUNKIT_BASH override -> derive from
  `where git` -> standard install paths), refuses System32, and fails loudly with
  install guidance. (2) `setup.sh` and `cursor-session-start.sh` no longer depend
  on `python3` (absent or a Store stub on many Windows machines): all JSON and
  checksum work now uses Node, which the kit already requires. Paths passed into
  Git Bash are normalized to forward slashes.

- **(v2.0)** — Major release. Project name: **anpunkit**; distributed
  as `npx create-anpunkit`. Five locked features: (1) **TDD-first** via a SCAFFOLD
  step (implementer writes stubs only; test-author writes the suite blind against
  stubs; RED gate must fail for the right reason; implementer fills to GREEN);
  (2) **Portability split** — canonical `AGENTS.md` holds all methodology, `CLAUDE.md`
  becomes a thin `@AGENTS.md` shim (anti-drift invariant: every rule in exactly one
  place); (3) **Regression aggregation** — `tests/regression/` mock corpus as an
  always-on guard with a hard ENDPOINTS coverage gate at CLOSE; (4) **Upgrade-safe
  installer** — manifest-driven, non-destructive `setup.sh` + `create-anpunkit` npx
  package; (5) **Multi-tool adapters** — one canonical `commands.src/` body generates
  Claude Code + Cursor commands, with Cursor at near-parity via `.cursor/hooks.json`
  lifecycle hooks (Codex dropped). New decision entries §5.28–§5.32. New files:
  `AGENTS.md`, `commands.src/*`, `.cursor/*`, `.claude/anpunkit-manifest.json`,
  `scripts/regression.sh`, `tests/regression/`, `create-anpunkit/`.
  NOTE: the V2_0_REQUIREMENTS doc referenced §5.26–§5.30, but the real v1.5 log
  already used §5.26–§5.27 (the shared-KB entries), so the v2.0 entries continue
  cleanly at §5.28–§5.32.

- **(v1.5)** — Shared KB mechanism added:
  (1) **`/store-wisdom` command**: analyzes resolved issues + completed research
  in the current project, proposes promotion candidates for human review, then
  commits and pushes approved entries to a shared `anpunkit-kb` GitHub repo.
  (2) **Researcher KB check (step 0)**: both DESIGN and IMPL modes check
  `docs/.kb-snapshot.md` before any web search. Fresh hits short-circuit web
  research; stale hits are treated as weak signals and re-researched.
  (3) **Session-start KB pull**: if `.claude/kb-config.json` exists, the
  SessionStart hook pulls the KB and writes a snapshot to `docs/.kb-snapshot.md`
  with staleness markers. Fails silently if offline.
  (4) **`setup.sh` KB prompt**: asks for the local KB repo path + verifies
  connectivity via `git ls-remote` before writing `.claude/kb-config.json`.
  New file: `docs/.kb-snapshot.md` (gitignored, session-local).

- **(v1.4)** — Four new capabilities added:
  (1) **Design-researcher + double grill in /overview**: `researcher` gains a
  DESIGN mode for pre-planning domain/constraint research. `/overview` flow is
  now: grill (round 1) → design-researcher → re-grill (round 2, always, research-
  informed) → OVERVIEW.md (written after round 2) → planner. Round 1 answers are
  working context only — OVERVIEW.md is not written until after the re-grill.
  (2) **Deployment in last phase**: `planner` is required to include a deploy task
  block in the final code phase. Enforced at planning time.
  (3) **Usage endpoint summary on final phase close**: `/phase` CLOSE detects
  IS_FINAL_PHASE; after synthesizer runs, surfaces a "READY TO USE" block with
  the deployed base URL and full ENDPOINTS.md table.
  (4) **Final-phase doc update pass**: `synthesizer` receives a FINAL PHASE
  signal and runs an extended pass updating OVERVIEW.md and README.md.
  New file: `docs/ENDPOINTS.md` — API endpoint catalogue maintained by
  implementer per phase. `researcher` gains two modes (DESIGN / IMPL);
  design research writes to `design-<slug>.md`; INDEX.md updated to note the
  prefix convention.

---

## 1. Problem statement

Six recurring failure modes in a 10-point manual development practice:

1. Issue log missed — agents repeated known dead ends.
2. Manual navigation every session — wasted time re-orienting.
3. Agents over-struggling on bugs — no circuit breaker.
4. Context rot — debug noise filled the orchestrator's window.
5. No subagent orchestration — everything happened inline.
6. Uncleaned handoff files — STATE.md grew unbounded.

---

## 2. Core architectural insight

**Mandatory steps live in hooks. Discretionary steps live in agents/skills.**

Hooks are deterministic — they cannot be skipped, forgotten, or reasoned around.
Agents are model-driven — they reason, but they can be wrong or lazy.

The six failure modes above all came from putting "must happen" steps into
prompts (discretionary) rather than hooks (deterministic).

---

## 3. The orchestrator-subagent boundary

The main Claude Code session is the ORCHESTRATOR. It:
- reads STATE.md, PLAN.md, and ISSUES.md
- dispatches subagents for scoped work
- gates on results (circuit breaker, phase gate)
- communicates with the user

Subagents cannot address the user directly. All escalation is orchestrator-mediated.
This keeps the human interface clean and predictable.

---

## 4. Test layering

Three layers, each with a different trust level:

1. Mock suite (fast, no external dependency) — written blind by test-author.
2. Real API suite (real HTTP + real Azure) — written blind by test-author.
3. Browser E2E (Playwright, ROPC auth) — written blind by e2e-runner.

Phase gate = layer 2 passes + (if frontend) layer 3 passes.
Layer 1 alone never closes a phase. "Mock-green" is not done.

---

## 5. Decision log

### 5.1 Agent Teams deferred
Cross-session agent parallelism (Claude Code Agent Teams) deferred. Single
orchestrator + sequential subagents is simpler to reason about and debug.
Revisit when the sequential model proves to be the bottleneck.

### 5.2 Three hooks, not more
SessionStart, PreCompact, SubagentStop. These three cover the mandatory
injection (start), context protection (compact), and lightweight trace (stop).
A SessionEnd hook was discussed but rejected — it would be a mechanical snapshot
only and adds complexity without fixing a real failure mode.

### 5.3 synthesizer is Haiku, not Opus
Compression and dedup is mechanical, not reasoning-heavy. Haiku is faster and
cheaper. Opus is reserved for agents that need to reason about design
(planner, infra-provisioner, implementer, debugger).

### 5.4 /clear does not lose hooks
`/clear` resets the context window but not the hook configuration. SessionStart
fires again on the next turn, re-injecting STATE.md + ISSUES.md. Hook wiring
lives in `.claude/settings.json`, not in the context.

### 5.5 researcher writes to file, returns terse summary
Full research output is written to `docs/research/<slug>.md`. The orchestrator
receives only a terse summary + path. This keeps the orchestrator's context
clean — it reads the file only if it needs detail.

### 5.6 Circuit breaker: warn at 2, hard-stop at 3
Two attempts are enough to rule out the obvious hypotheses. Three attempts
without a fix signals the frame is wrong — more in-place attempts waste budget.
Hard-stop at 3 forces either /unstuck (re-research) or human intervention.

### 5.7 Escalation is always two hops
Subagent → orchestrator → user. A subagent that directly asks the user would
fragment the conversation and make the orchestrator's state inconsistent.

### 5.8 Skill vendoring is fallback-only
caveman and grill-me are vendored in `.claude/skills/` as fallback copies only.
The global `~/.claude/skills/` copy is authoritative. The vendored copy is used
only if the global is missing. This prevents the project copy from diverging
from the user's customized global version.

### 5.9 DESIGN_LOG.md is append-only
History is never rewritten. Decisions that turn out to be wrong get a new entry
explaining the correction — not an edit to the original. This preserves the full
reasoning trail and prevents silent revisionism.

### 5.10 MSAL auth: ROPC + dedicated test account, never UI automation
Browser E2E must not drive the Microsoft login UI — it is brittle, MFA-blocked,
and unsupported. ROPC flow with a dedicated test account (MFA excluded via
Conditional Access policy) is the correct approach. The token is injected
directly into the MSAL localStorage cache, bypassing the UI entirely.

### 5.11 Failure classification: LOGIC FAIL vs SERVICE UNAVAILABLE
Outages, rate limits, auth expiry, and stack-not-ready states are environment
failures, not code bugs. They must not consume the debug budget (3-attempt
circuit breaker). The test-author and e2e-runner classify every failure before
routing — only LOGIC FAIL reaches the debugger.

### 5.12 Phase gate requires real API + real E2E, not mock-green
Mocks verify that the code compiles and the wiring is correct. They cannot
verify that the real Azure service behaves as expected. The phase gate requires
both the real API suite and (for frontend phases) the real browser E2E to pass.

### 5.13 Hook path resolution on Windows (Git Bash)
Claude Code on Windows runs hook commands under Git Bash. The hook command must
use a bare `bash` prefix (`bash .claude/hooks/session-start.sh`), not an
explicit path like `C:\Program Files\Git\bin\bash.exe`. The explicit path
triggers a Claude Code argument-splitter bug that silently misfires the hook.

### 5.14 LF normalization in setup.sh
Windows Git clones may CRLF-convert shell scripts even with `.gitattributes`.
`setup.sh` runs `sed -i 's/\r$//'` on all `.sh` files as a self-healing step.
The `.gitattributes` file pins `*.sh` to LF for future clones.

### 5.15 Hook silent injection (Claude Code 2.1.x)
SessionStart output is injected into the model context silently — no visible
UI banner. This is expected behavior in Claude Code 2.1.x. The reliable test:
ask Claude "what does my STATE.md say?" in a fresh session. A correct answer
without a file read = hooks working.

### 5.16 CLAUDE_PROJECT_DIR fallback
Hooks use `cd "${CLAUDE_PROJECT_DIR:-.}"` — falls back to `.` (current
directory) if the env var is unset. This handles both the normal Claude Code
invocation (where the var is set) and direct bash invocation for testing.

### 5.17 Bicep over raw Azure CLI for IaC
Bicep provides declarative, repeatable, reviewable infrastructure definitions.
Raw `az` commands are imperative and not idempotent. The what-if gate requires
a declarative format to produce a meaningful diff.

### 5.18 E2E target is design-determined
local-docker or azure-deployed, set in INFRA.md by infra-provisioner. Not
hardcoded. `e2e-stack.sh up` is a reachability check when EXTERNAL=1.

### 5.19 Test data lifecycle — seeding is deployment, not E2E
`e2e-stack.sh` seed/cleanup removed. Test data = deployment-phase concern.

### 5.20 Clone-direct distribution (v1.3)
`install.sh` removed; replaced by `setup.sh` (in-place, post-clone). Kit is
the repo itself — `git clone` then `bash setup.sh`.

### 5.21 Design-researcher + double grill (v1.4)
**Problem:** grill-me in /overview ran with zero domain knowledge, producing
shallow questions. The planner then designed phases against unverified
assumptions about service capabilities, quotas, and architectural constraints.

**Decision:** split the pre-planning flow into two research passes:
- Grill round 1: captures initial scope from the user's own knowledge.
- Design research (DESIGN mode on researcher): verifies external service
  capabilities, quotas, architectural constraints, cost surprises. Writes to
  `design-<slug>.md`.
- Grill round 2: always runs (not conditional on "unknowns found"); seeded with
  round-1 answers + full research findings. Builds complete, research-informed
  understanding before OVERVIEW.md is written.

**Why re-grill always (not conditional):** Research always produces new context,
even when it finds no blockers. Knowing a service *does* support a pattern is
just as valuable for shaping the interview as knowing it doesn't.

**OVERVIEW.md written after round 2:** round-1 answers are working context only.
The planner receives the fully-informed picture.

### 5.22 Deployment mandatory in last phase (v1.4)
**Problem:** deployment was not a guaranteed part of the plan. Projects could
complete all implementation phases without ever deploying, leaving no
confirmed live URL.

**Decision:** planner is instructed (hard rule) that the final code phase must
always include a deploy task block: deploy to Azure, smoke-test the deployed
URL, write the URL back to INFRA.md, update ENDPOINTS.md. Enforced at
planning time in planner.md. /replan is required to preserve this invariant
when it re-plans pending phases.

### 5.23 Usage endpoint summary on final phase close (v1.4)
**Problem:** after the last phase completes, the user has no immediate
actionable summary — they must hunt across INFRA.md and ENDPOINTS.md.

**Decision:** /phase CLOSE detects IS_FINAL_PHASE (no further pending phases
in PLAN.md). After synthesizer runs, the orchestrator reads docs/ENDPOINTS.md
and docs/INFRA.md and surfaces a "READY TO USE" block: deployed base URL,
full endpoint table, quick-start curl example, auth notes.

**Implementation:** orchestrator reads ENDPOINTS.md directly (no subagent
dispatch needed — it's a small file the implementer maintains).

### 5.24 Final-phase doc update pass via synthesizer (v1.4)
**Problem:** after project completion, OVERVIEW.md and README.md still
reflect the planning-time state — not the delivered state.

**Decision:** synthesizer receives a FINAL PHASE signal from /phase CLOSE
(and /synthesize when it detects no remaining pending phases). Extended pass
appends a "Final state" section to OVERVIEW.md and updates the project README.md
status to "Production — deployed at <URL>". synthesizer does NOT touch
DESIGN_LOG.md or INFRA.md or ENDPOINTS.md — those are owned by other agents.

### 5.25 Shared KB — separate repo, not inside anpunkit (v1.5)
**Problem:** research findings and resolved issues die with their project repo.
Every new project re-discovers the same Azure/Databricks gotchas.

**Decision:** a separate `anpunkit-kb` GitHub repo accumulates cross-project
findings. Separate repo (not a folder inside anpunkit) because:
- it must survive anpunkit upgrades without being overwritten
- it is shared across machines independently
- a project that opts out should not carry KB content in its repo

**Why GitHub over other options:** git handles auth transparently (SSH key or
HTTPS credential manager). The remote is configured once in `kb-config.json`
and verified at setup time via `git ls-remote`. No additional infrastructure.

### 5.26 KB is loaded once per session (static snapshot) (v1.5)
**Problem:** if the researcher pulled from KB on every call, mid-session updates
from other machines could change what the researcher "knows" unpredictably.

**Decision:** pull once at session start (SessionStart hook), write to
`docs/.kb-snapshot.md`. The snapshot is static for the session. The researcher
reads only the snapshot, never the live KB. This is predictable and fast.
Stale entries (research > 6 months) are flagged in the snapshot at load time —
the researcher treats them as weak signals and re-researches locally.

### 5.27 /store-wisdom is human-gated, never automatic (v1.5)
**Problem:** automatic KB writes could promote incorrect findings, open issues,
or project-specific noise to the shared store.

**Decision:** `/store-wisdom` is the only write path to the KB. It is a slash
command, not a hook — explicitly triggered by the user. It presents each
candidate for approval before writing. Only resolved issues (not open ones) and
generalizable research (not project-specific config or debug traces) qualify.
This keeps the KB signal-dense rather than becoming a dump.

**Staleness rewrite via /store-wisdom only:** when the researcher re-researches
a stale KB entry locally, the new findings stay in `docs/research/`. They are
only written back to the KB when the user explicitly runs `/store-wisdom`. The
hook never modifies the KB repo.

---

### 5.28 Fail-first TDD via a SCAFFOLD step (v2.0)
**Problem:** tests-after let the implementation shape the test; honor-system
"write tests first" drifts. (§5.5 was the original misread of this.)

**Decision:** TDD phases run `SCAFFOLD -> RED -> GREEN`. The implementer writes
interface stubs only (no logic); the test-author writes the suite blind against
those stubs; the RED gate requires every acceptance test to COLLECT cleanly and
FAIL (assertion / NotImplemented). Green-on-stubs is caught and rejected. Then the
implementer fills to GREEN. Blindness is now STRUCTURAL — there is no logic to
peek at — not honor-system. `TDD_PHASE` is a BOOLEAN gate ("does the phase add a
public callable surface assertable from the spec?"); size thresholds were rejected
as a bad proxy that reintroduces the §5.5 misread. On ambiguity, default true but
state the classification so a human can override before SCAFFOLD fires. Rule 11
(scoped no-rationalization) forbids dodging the gate by downgrading a phase or
routing it through `/quick`.

**Rejected:** classic TDD, tests-after, a separate stub-writer agent. **Cost:**
+1 dispatch per TDD phase. Partially resolves §5.5.

### 5.29 AGENTS.md / CLAUDE.md portability split (v2.0)
**Problem:** all methodology lived in a Claude-only `CLAUDE.md`; other tools could
not consume it, and any second config file risked drifting out of sync.

**Decision:** canonical `AGENTS.md` (open standard) holds every rule, role,
procedure, and ritual. `CLAUDE.md` becomes a thin shim: a bare top-level
`@AGENTS.md` import plus Claude-native wiring (subagent roster, hook-to-ritual
mapping, platform notes) and restates NO rule. Anti-drift invariant: every rule
lives in exactly one place; duplication is a defect. `@import` is confirmed
reliable (official Claude Code docs: `@path`, recursive to depth 5, not evaluated
in code spans). `setup.sh` VERIFY hardens it: bare unfenced import + AGENTS.md on
disk + a SENTINEL string, else loud-fail `exit 1`. Token saving is explicitly NOT
the motivation (imports expand inline).

**Rejected:** fused + hand-written second file, build-time generation of the rule
source, per-tool full configs.

### 5.30 Regression aggregation — mock corpus guard + ENDPOINTS gate (v2.0)
**Problem:** a contract built in an early phase could be silently broken by a later
phase; nothing re-checked it.

**Decision:** `tests/regression/` holds cross-phase contract tests (corpus =
`ls tests/regression/`, visible and auditable). `tests/phase-<n>/` holds
phase-local tests. The accumulated MOCK corpus is the always-on guard, run at
every phase CLOSE, after `/quick`, and after `/replan`; the full REAL corpus runs
only at the final phase and after `/replan`. mock-vs-real is a fixture/env flag
(`TEST_MODE`) on the same test, not duplicated files. CLOSE asserts ENDPOINTS
coverage: every `docs/ENDPOINTS.md` entry must have >=1 regression test; zero ->
fail hard. Rule 5 extended accordingly. No new subagent.

**Rejected:** re-run all REAL every phase (doesn't scale); a `@regression` marker
(a forgotten marker = a silent gap); no cross-phase guard (the status-quo
failure). Residual soft edge (accepted): non-endpoint contracts still rely on
author judgment.

### 5.31 Upgrade-safe installer + npx distribution (v2.0)
**Problem:** clone-direct could clobber a user's existing files on upgrade; there
was no end-user-friendly install path.

**Decision:** `npx create-anpunkit` (public) and clone+`setup.sh` coexist (end
users vs kit developers). A declarative `.claude/anpunkit-manifest.json`
(version + per-file sha256) drives a non-destructive upgrade: kit-owned files are
refreshed; user-modified kit files are KEPT and the new version written as
`<file>.anpunkit-new` (+ `--force` to overwrite); user-owned files are never
touched; hybrid files (`settings.json`, `.cursor/hooks.json`, `.gitignore`,
`DESIGN_LOG.md`) are merged idempotently. A timestamped `.anpunkit-backup-*/` is
written before any upgrade write, and `--dry-run` prints the plan without writing
— the install-time analogue of the `az deployment what-if` review gate. The npx
bin reimplements NO logic; it delegates to `bash setup.sh --src <template>`.
NOTE: `.claude/commands/` is now GENERATED output, so a v1.5->v2.0 upgrade moves
the command source-of-truth from the file to the generator (handled by checksum
logic; called out for the upgrade smoke test).

**Rejected:** clobbering reinstall; reimplementing setup.sh logic in Node (drift);
imperative per-version migrations as the default.

### 5.32 Multi-tool adapters — Claude Code + Cursor (v2.0)
**Problem:** the kit was Claude-only; maintaining parallel per-tool command copies
by hand would drift.

**Decision:** one canonical body per procedure in `commands.src/<name>.md`,
generated at install into `.claude/commands/` (Claude) and `.cursor/commands/`
(Cursor; frontmatter stripped, `$ARGUMENTS` works). Cursor reaches near-parity:
`.cursor/rules/anpunkit.md` points at `AGENTS.md` for methodology, and
`.cursor/hooks.json` wires `sessionStart`/`preCompact`/`subagentStop` to the SAME
shared hook scripts used by Claude (one copy of each script; only the wiring
differs). Codex DROPPED entirely (its repo-committed command path is deprecated
home-dir custom-prompts; divergent UX). Honest degradation for Cursor is captured
in the README "verify at build" notes (context injection, named subagents, hook
path resolution).

**Rejected:** symmetric Claude/Cursor/Codex generation; hand-maintained per-tool
copies; generating into `~/.codex/prompts`; claiming full support for every tool.

**Verified at build (cursor.com/docs/hooks, /docs/subagents,
/docs/reference/third-party-hooks — 2026-06):** all three open items resolved.
(1) `sessionStart` DOES inject context via an `additional_context` JSON output
field; Cursor expects JSON where Claude injects raw stdout, so the wiring runs
the shared body through a thin `cursor-session-start.sh` JSON-envelope wrapper
(body remains one copy). (2) Cursor DOES support named subagents and reads
`.claude/agents/*.md` natively via its documented Claude-compatibility path — no
`.cursor/agents/` duplication; `model: haiku/opus` tiers fall back to
inherit/compatible. (3) Project `.cursor/hooks.json` commands resolve from the
PROJECT ROOT (not `.cursor/`); wiring uses `bash .claude/hooks/<script>.sh`, and
Cursor sets `CLAUDE_PROJECT_DIR` as a compat alias so shared scripts run
unchanged. Cursor's `preCompact` is observational only — acceptable (the
snapshot is a side effect). Decision: explicit native `.cursor/hooks.json`
wiring. Rejected: relying on Cursor's third-party loading of
`.claude/settings.json` hooks (requires a manual "Third-party skills" settings
toggle — silent no-op if forgotten — and would double-fire if combined with
native wiring).

---

## 6. Current file inventory
```

anpunkit/
CLAUDE.md                       always-loaded project memory
README.md                       user-facing guide
.gitattributes                  pins .sh to LF
.gitignore                      runtime scratch files excluded (committed)
.env.test.example               E2E secrets template
setup.sh                        one-time post-clone setup + optional KB config
playwright.config.ts            E2E config
docker-compose.test.yml         app containers -> real Azure (TEMPLATE)
.claude/
settings.json                 wires the 3 hooks
kb-config.json                shared KB path + remote (optional, written by setup.sh)
hooks/
session-start.sh            injects STATE, ISSUES, INDEX, rules, Azure nudge, KB snapshot
pre-compact.sh              snapshots before compaction
subagent-stop.sh            lightweight trace per subagent
agents/
researcher                  DESIGN mode + IMPL mode; KB snapshot check step 0 — Haiku
planner                     OVERVIEW -> PLAN.md, Phase 0 first, last phase deploys — Opus
infra-provisioner           Bicep, what-if, apply, INFRA.md + .env.test — Opus
implementer                 one phase, no tests, maintains ENDPOINTS.md — Opus
test-author                 blind tests, mock + real API suites — Opus
debugger                    isolated debug context, writes to file — Opus
e2e-runner                  Playwright E2E, reads INFRA.md for target — Opus
synthesizer                 per-phase cleanup + final-phase extended pass — Haiku
commands/
overview                    design-research + double grill + plan
infra                       provision/verify Azure infra
phase                       run one phase; final-phase: endpoint summary
quick                       small direct change
unstuck                     deep re-research after circuit breaker
synthesize                  compress handoff docs; final-phase: extended pass
replan                      revise PLAN.md; auto design-research on new services
log-issue                   append to ISSUES.md
log-decision                append to DESIGN_LOG.md
store-wisdom                promote findings to shared KB (human-gated)
skills/
karpathy-guidelines         kit-owned coding + debug discipline
caveman                     fallback only
grill-me                    fallback only
e2e/
global-setup.ts               ROPC token fetch + MSAL injection
scripts/
auth-setup.sh                 session Azure credential check
e2e-stack.sh                  up|down lifecycle
infra/
main.bicep                    top-level Bicep (generated)
params.json                   parameters, no secrets (generated)
modules/                      per-service Bicep modules (generated)
docs/
STATE.md                      operational handoff (rewritten each phase)
ISSUES.md                     error log (deduped by synthesizer)
PLAN.md                       phase plan (Phase 0 first; last phase deploys)
HISTORY.md                    one line per finished phase
DESIGN_LOG.md                 architectural rationale
OVERVIEW.md                   project scope (written after double grill)
INFRA.md                      Azure resource manifest + cost estimates
ENDPOINTS.md                  API endpoint catalogue (maintained by implementer)
research/INDEX.md             searchable map (design-*, impl, debug-*)
.snapshots/                   pre-compact recovery markers (gitignored)
.kb-snapshot.md               KB INDEX loaded this session (gitignored, session-local)

```
---


### v2.0 additions to the inventory

```
AGENTS.md                          portable single source of truth (methodology + rules + SENTINEL)
CLAUDE.md                          thin @AGENTS.md shim (Claude-native wiring only)
commands.src/<name>.md             canonical command bodies (one per procedure) — source of truth
.claude/commands/<name>.md         GENERATED from commands.src (Claude adapter)
.cursor/commands/<name>.md         GENERATED from commands.src (Cursor adapter, frontmatter stripped)
.cursor/rules/anpunkit.md          GENERATED pointer at AGENTS.md (Cursor methodology)
.cursor/hooks.json                 Cursor lifecycle wiring -> shared .claude/hooks/*.sh (hybrid-merge)
.claude/anpunkit-manifest.json     {version, files:[{path, sha256}]} — drives upgrade taxonomy
scripts/regression.sh              runs tests/regression/ (default mock, --real)
tests/regression/                  cross-phase contract corpus (the regression guard)
tests/phase-<n>/                   phase-local suites
create-anpunkit/                   npx package (package.json, bin/cli.js, build.sh) -> `npx create-anpunkit`
```

`setup.sh` is rewritten as the non-destructive installer engine (manifest-driven
ownership taxonomy, adapter generation, idempotent JSON hook merge, VERIFY,
backup, `--dry-run`).

## 7. How each original problem maps to its fix

| Problem | Fix |
|---|---|
| 1 miss issue log | SessionStart hook injects open ISSUES.md every session |
| 2 manual navigation | SessionStart hook injects STATE.md + git + research INDEX |
| 3 stuck too long | warn at 2; first hard-stop at 3 stops and asks; `/unstuck` for deep re-research |
| 4 context rot in debug | `debugger` isolated context + writes noise to file |
| 5 want orchestration | 8 scoped subagents; `/phase` orchestrates them |
| 6 handoff bloat | `synthesizer` + PreCompact hook; HISTORY.md for long log |
| 7 Azure auth friction + infra ad-hoc | `auth-setup.sh` + `infra-provisioner` Phase 0 |
| 8 re-discovering same gotchas across projects | KB snapshot at session start; researcher checks before web; `/store-wisdom` promotes findings |

---

## 8. Known gaps & template placeholders

1. `docker-compose.test.yml` — build contexts and ports are TEMPLATE values.
2. `e2e/global-setup.ts` — MSAL cache-key shape is a stub; adjust for app's
   `@azure/msal-browser` version/config.
3. caveman vendored copy is the base version, not the user's ULTRA variant.
4. Visual-regression testing — explicit non-goal.
5. Agent Teams / cross-session parallelism — deferred.
6. SessionEnd guard hook — discussed, not built.
7. Attempt counter is model self-tracked.
8. `infra/modules/*.bicep` — generated per-project by infra-provisioner.
9. `scripts/setup-entra.sh` — generated by infra-provisioner when needed.
10. Test data seeding scripts — deployment-phase concern.
11. `infra/params.json` — no secrets; Key Vault references for secrets.
12. docs/ENDPOINTS.md — starter template only; populated by implementer.
13. KB domain structure — fully dynamic (inferred by /store-wisdom from content).
    No pre-seeded domain directories ship with the kit.
14. Multi-machine KB sync — git push/pull via SSH or HTTPS credential manager.
    No automatic sync outside of session-start pull and /store-wisdom push.

---

## 9. Principles to preserve in any future upgrade

1. Mandatory steps live in hooks; discretionary in agents/skills.
2. Subagents cannot talk to the user. Escalation is always orchestrator-mediated.
3. The orchestrator routes; it does not implement or debug.
4. The phase gate is a REAL test. A mock suite never closes a phase.
5. Noisy work writes full output to `docs/research/` and returns only
   terse summary + path — keeps the orchestrator context clean.
6. Tests are written blind — this is the unbiased-test guarantee.
7. Never script the Microsoft login UI.
8. Fail loud, never silent — especially hook wiring.
9. Honest failure classification — environment issues never burn the debug budget.
10. Azure infra is Phase 0: provisioned once, reviewed before apply, recorded in INFRA.md.
11. Plan before code: design-research + double grill before OVERVIEW.md is written.
    The planner must never design phases against unverified assumptions.
12. Deployment is always in the last phase — never omitted, never a separate phase.
13. The shared KB is human-gated at both ends: you approve before push (/store-wisdom),
    and findings are static within a session (KB snapshot). The KB never writes itself.
