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

- **(v2.3)** — **Compression internalized + core/use-case separation + Cursor drop.**
  Two streams. **Stream A:** the external `caveman` skill (vendored fallback +
  "global-authoritative if installed" resolution + model-invoked triggers) becomes a
  kit-native, single-source, always-on reference (`.claude/ref/compression.md`) with
  two named profiles — `user` (human-facing, keeps the Auto-Clarity exception) and
  `internal` (agent↔agent, harder). ~40 scattered "Caveman ULTRA mode" phrases
  collapse to one-line profile pointers; exact-output artifacts are exempted by
  structural gates in the `spec-author` / `test-author` / `e2e-runner` prompts.
  **Stream B:** the invariant core (loop, gates, doc system, commands) is separated
  from web/Azure practice, which becomes preinstalled knowledge docs
  (`knowledge/webapp.md`, `knowledge/azure.md`) consulted deterministically by
  `researcher` at RESEARCH. New OVERVIEW flags — `project_type`, `infra_needed`,
  `e2e_kind`, `deploy_kind`, `knowledge_docs` — declared at `/overview`, bound
  per-phase at RESEARCH: Phase 0 exists iff `infra_needed`; the boundary run is
  selected by `e2e_kind`; the final phase completes `deploy_kind`. Cursor support is
  hard-dropped (Claude Code only). New decision entries §5.57–§5.71. NEW files:
  `.claude/ref/compression.md`, `knowledge/webapp.md`, `knowledge/azure.md`. REMOVED:
  `.claude/skills/caveman/`, `.cursor/**`, `.claude/hooks/cursor-session-start.sh`,
  and the installer tool-selection machinery. CUT from default install (embedded as
  templates in the knowledge docs): `playwright.config.ts`, `e2e/`,
  `docker-compose.test.yml`, `scripts/e2e-stack.sh`, `scripts/auth-setup.sh`.

- **(v2.2)** — **Spec-driven behavioral contract.** Closes the v2.1 residual:
  fabrication under a thin acceptance surface. In v2.1 a phase's whole contract was
  a single `acceptance:` line; `implementer` and `test-author` each independently
  elaborated it, and when both filled the same gap the same plausible-but-wrong way
  the suite went green on a broken core — TEST REVIEW (review of *coverage*, after
  RED) could not catch a faithful mapping to a *fabricated* criterion. The reframe:
  the reviewable, authoritative artifact is the SPEC, not the test. New mechanism —
  skeleton case-NAMES locked at `/overview` (planner) → per-phase concrete filling by
  a new **`spec-author`** (real inputs/expecteds in shared `fixtures/`) → **SPEC
  REVIEW** human gate UPSTREAM of code → tests GENERATED from the locked rows
  (deep-equality + matcher tokens for `data`, Playwright-from-descriptor for `ui`),
  sharing the same fixtures so a test cannot assert different values than the spec.
  Two new orchestrator-procedure scripts (`spec-staleness.sh`, `spec-conformance.sh`)
  replace the human TEST REVIEW gate. `test-author`/`e2e-runner` become harness
  EMITTERS; `implementer` reads the filled spec as its contract (author ≠ implementer).
  New decision entries §5.43–§5.56. New files: `.claude/agents/spec-author.md`,
  `scripts/spec-staleness.sh`, `scripts/spec-conformance.sh`, `tests/helpers/
  spec-assert.{py,ts}`, plus per-project `docs/spec-phase-<n>.md` + `fixtures/`.
  REMOVED: the v2.1 human TEST REVIEW gate (humans no longer review tests).
  NOTE: the v2.1 entries §5.33–§5.42 (TEST REVIEW gate, mandatory frontend E2E +
  evidence, DATAFLOW coverage, datasource understanding, auth proof/liveness,
  installer tool-selection) live in the v2.1 release bundle and the on-disk AGENTS.md
  hard rules; they were never merged into this on-disk log (a hybrid file). The v2.2
  decision numbers continue at §5.43 for continuity with the requirements doc.

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

### 5.8 Skill vendoring is fallback-only  *(superseded by §5.62, v2.3)*
caveman and grill-me are vendored in `.claude/skills/` as fallback copies only.
The global `~/.claude/skills/` copy is authoritative. The vendored copy is used
only if the global is missing. This prevents the project copy from diverging
from the user's customized global version.
> **Superseded (v2.3, §5.62):** caveman is internalized to `.claude/ref/
> compression.md`; grill-me becomes the sole authoritative source. The
> "global-authoritative if installed" resolution rule is dropped entirely.

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

### 5.32 Multi-tool adapters — Claude Code + Cursor (v2.0)  *(reversed by §5.69, v2.3)*
> **Reversed (v2.3, §5.69):** Cursor support is hard-dropped. The `.cursor/**`
> tree, `cursor-session-start.sh`, and the installer tool-selection machinery are
> removed; `commands.src/` now generates only `.claude/commands/`. Claude Code only.

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

> **Numbering note (v2.2).** §5.33–§5.42 are the v2.1 decisions (TEST REVIEW gate,
> mandatory frontend E2E + evidence, DATAFLOW transition coverage, datasource
> understanding, auth proof/liveness, installer tool-selection). They were recorded
> in the v2.1 release bundle and are reflected in AGENTS.md's hard rules, but were
> never merged into this on-disk log. v2.2 continues at §5.43 for continuity with the
> v2.2 requirements doc rather than renumbering.

### 5.43 Spec file is a per-phase artifact, not inline in PLAN.md (v2.2)
**Problem:** a phase's whole behavioral contract was one `acceptance:` line; two
agents independently elaborated it and could agree on the same wrong contract.
**Decision:** `docs/spec-phase-<n>.md` is a new per-phase artifact; `PLAN.md`'s
`acceptance:` stays a one-line summary, the spec is its concrete expansion. The spec
is self-correlating: a GENERATED header transcludes that phase's `acceptance:` line +
the in-scope `DATAFLOW.md` transition rows and embeds a staleness hash; only the
example-case table is human-authored. **Rejected:** expanding `acceptance:` inline in
PLAN.md — couples the contract to `/replan` churn, bloats PLAN, mixes phase-ordering
review with concrete-behavior review.

### 5.44 Two-layer baseline/delta — case-names up front, values per phase (v2.2)
**Decision:** lock behavior in two passes. (1) Up-front case-NAME contract at
`/overview`: for every DATAFLOW transition + every acceptance criterion, enumerate
the case names (happy / each edge / each failure + error code), no values yet —
skeleton spec files. (2) Per-phase concrete filling at `/phase` start (after
RESEARCH, before SCAFFOLD): `spec-author` fills real payloads/outputs grounded in
fresh research + the confirmed datasource baseline. **Rationale:** the only design
that gives BOTH "complete requirements locked before implementation" (names up front)
and "values grounded in real facts, not plan-time guesses" (per-phase fill). Mirrors
the established baseline/delta shape (datasource understanding, DATAFLOW coverage).

### 5.45 Skeleton→filled single file; "no unfilled stub" is the conformance invariant (v2.2)
**Decision:** skeletons are generated at `/overview` (names + `TBD`); `spec-author`
fills in-place. Invariant: no `TBD` may remain when `spec-conformance.sh` runs
(between RED and GREEN). **Consequence:** a case that cannot be filled from research
is escalated as UNDERSPEC / `CASE-SET-DIVERGENCE` BEFORE SCAFFOLD, not discovered at
GREEN.

### 5.46 Case structure: table row + boundary-typed fixture-ref (v2.2)
**Decision:** each case is one row — `case-id | covers | boundary | input-ref |
expected-ref | error-code | volatile`. `covers` = a DATAFLOW transition-id
(convention `Object:from->to`, no new DATAFLOW column) or acceptance criterion-id
(`ACC-<k>`). `boundary` ∈ {`data`,`ui`}. Refs point to `fixtures/<case-id>-*.json`
(scalars may inline). **Key property:** the harness loads the SAME fixture files the
spec row references — transcription from spec to test is STRUCTURAL, not honor-system;
a test physically cannot assert different values than the spec.

### 5.47 Boundary test is system-of-record per case; optional mock mirror (v2.2)
**Decision:** every case has exactly one BOUNDARY test — `data`: real
HTTP/CLI/message vs the running backend + real services (v2.1's "real API suite");
`ui`: Playwright vs the deployed/local-docker target (v2.1's E2E). The boundary test
is the phase gate; green mock alone never closes (rule 5 / §5.38 preserved). A mock
mirror is optional, shares the fixture + comparator via `TEST_MODE`. "E2E" is
generalized to *outer-boundary*, not browser-specific: on `has_frontend: false` all
cases are `data` and `ui` rows are invalid.

### 5.48 Human TEST REVIEW removed; assertion is generated deep-equality (v2.2)
**Decision:** remove the v2.1 human TEST REVIEW gate. Humans never review tests.
Tests are not authored — a harness generator emits a deep-equality assertion against
`fixtures/<case-id>-expected.json` per case row. SPEC REVIEW (§5.50) is the
human gate; it sits upstream (before SCAFFOLD), reviews concrete behavior in plain
language, and is the correctness-bearing moment TEST REVIEW was not (wrong thing,
wrong layer: TEST REVIEW reviewed coverage and asked humans to read assertions).

### 5.49 Volatile fields use matcher tokens in the fixture (v2.2)
**Decision:** volatile fields (generated IDs, timestamps, order, cursors) are matched
by TYPE, not excluded. The expected fixture carries sentinels — `<UUID>`, `<ISO8601>`,
`<ANY_STRING>`, `<ANY_NUMBER>`, `<UNORDERED>`, `<MATCHES:regex>`. The per-language
comparator `tests/helpers/spec-assert.*` honors them. A token asserts PRESENCE +
SHAPE, never "ignore this field" (a missing volatile field still fails). The
comparator is bounded + kit-versioned (one impl per supported language); no
per-project comparator code.

### 5.50 SPEC REVIEW — per-phase human gate on concrete fillings (v2.2)
**Decision:** after `spec-author` fills + `spec-staleness.sh` passes, the orchestrator
surfaces filled cases as FALSIFIABLE CLAIMS; the human confirms/corrects. Rejection
classification: wrong expected → fix row + fixture (no re-research); wrong input shape
→ re-dispatch `spec-author`; new case OR contradicted case → hard re-entry (§5.52).
Unskippable on TDD phases; absent on non-TDD. Replaces v2.1 human TEST REVIEW.

### 5.51 Up-front case-name completeness folded into existing /overview approval (v2.2)
**Decision:** the existing end-of-`/overview` approval (PLAN.md + DATAFLOW.md) is
EXTENDED to confirm the cross-phase skeleton case-name set (per phase: covered
transition/acceptance ids + enumerated case names, no values). One confirmation, one
surface, no new gate — the names derive from the same PLAN + DATAFLOW being approved.

### 5.52 Any case-set divergence at phase time → hard re-entry (v2.2)
**Decision:** if phase-time RESEARCH reveals a case not enumerated up front, or one
that contradicts an enumerated case (locked contract impossible), the phase STOPS.
`spec-author` returns `CASE-SET-DIVERGENCE`; the human amends the up-front skeleton;
re-confirms the amended case(s) + any case sharing their `covers` id (the staleness
hash certifies the unchanged remainder — not re-read); `spec-author` re-fills from
scratch. **Rationale:** AI writes code; the human owns the contract. No fold-forward,
no AI amendment of the case-name set.

### 5.53 Dedicated spec-author agent; author ≠ implementer invariant (v2.2)
**Decision:** a new `spec-author` (Opus) fills the per-phase spec + fixtures after
RESEARCH, before SPEC REVIEW; returns `CASE-SET-DIVERGENCE` when a case can't be
filled from real facts or research reveals an unlisted branch. It is NOT
`implementer`. The **author ≠ implementer** invariant replaces v2.1's test-author
blindness invariant: `implementer` reads the filled spec as its contract (normal
spec-driven development), `test-author` becomes a harness emitter (reads spec rows,
generates the assertion harness, authors no assertions).

### 5.54 UI boundary cases use generated Playwright; e2e-runner is an emitter (v2.2)
**Decision:** for `ui` cases, `e2e-runner` stops authoring blind and EMITS a
Playwright assertion from the case's `fixtures/<case-id>-ui.json` descriptor. The
descriptor vocabulary is closed + kit-versioned: `visible`, `text-equals`, `enabled`,
`count`. Screenshot-on-each-UI-existence-assertion (v2.1 §5.35) is retained as the
visual backstop. `ui` cases have no mock mirror (the browser is the boundary). On
`has_frontend: false`, `ui` rows are invalid.

### 5.55 spec-staleness.sh + spec-conformance.sh as orchestrator-procedure scripts (v2.2)
**Decision:** two new scripts, same idiom as `regression.sh` (`set -euo pipefail`,
nonzero = loud fail). `spec-staleness.sh` re-hashes the current PLAN acceptance line +
in-scope DATAFLOW rows and compares to the spec's embedded header hash (`stamp`
subcommand embeds it at `/overview`/regenerate; default `check` compares); runs after
SPEC fill + at SPEC REVIEW entry. `spec-conformance.sh` asserts no `TBD` remains and
every case-id is cited by a boundary test (`# spec: <case-id>`); runs between RED and
GREEN, replacing the human TEST REVIEW gate. Both port to Cursor for free (same
`/phase` body, same bash scripts — no new hook wiring). **Design choice (impl):**
hashing lives ONLY in the script (a `stamp` subcommand), not duplicated in agent
prompts; transition-ids are derived (`Object:from->to`) so DATAFLOW needs no new column.

### 5.56 Rule 14 re-seamed: transition→case reachability; conformance owns case→test (v2.2)
**Decision:** v2.1 rule 14 (DATAFLOW transition coverage) is re-seamed. New
responsibility: every reachable DATAFLOW transition must have ≥1 FILLED CASE in
`docs/spec-phase-<n>.md` (was: ≥1 test in `tests/regression/`). Reachability judgment
unchanged (orchestrator decides at CLOSE; unreachable list PENDING; all live by final
phase or FAIL HARD). The case→test half moves to `spec-conformance.sh` (every case-id
cited by a boundary test, which by placement convention lands in `tests/regression/`).
The full guarantee is preserved by the chain: reachable transition → filled case
(rule 14) → cited boundary test (conformance) → regression corpus (placement). The
ENDPOINTS coverage gate is unchanged and orthogonal (endpoint-keyed vs behavior-keyed).

**Numbering reconciliation (v2.2).** The requirements doc's hard-rule table labeled
new rules 12–16, but its own "Non-changes" section retains the frontend-E2E (old 13),
datasource (old 15) and auth (old 16) rules — so the table is illustrative, not literal.
AGENTS.md realizes a coherent set: rule **12** = SPEC REVIEW (reuses the slot freed by
the removed TEST REVIEW); rule **14** = re-seamed DATAFLOW (kept in place); rules
**13/15/16** keep their v2.1 meanings (frontend E2E / datasource / auth); the remaining
new rules append as **17** (spec staleness), **18** (spec conformance), **19** (author ≠
implementer). This preserves every existing `hard rule N` cross-reference except 12.

### 5.57 Compression rules: standalone kit-native reference file (v2.3)
**Decision:** compression rules live in exactly one kit-native reference file,
`.claude/ref/compression.md` (replaces the vendored `caveman` skill). AGENTS.md and
every crafted subagent prompt POINT to it; none restate the rules. Not placed under
`.claude/skills/` — no description/trigger surface, so §5.61 is satisfied
structurally, not by discipline.
**Rejected:** rules inside AGENTS.md (subagents don't inherit it — they run their own
crafted prompts by design); rules duplicated per prompt (drift).

### 5.58 Two named compression profiles (v2.3)
**Decision:** `user` (human-facing; keeps the Auto-Clarity exception — security
warnings, irreversible-action confirmations, multi-step sequences, clarification
requests) and `internal` (agent→agent; harder compression, no clarity exception).
**Rejected:** one rule set with a conditional exception (implicit, weaker than a named
structural declaration).

### 5.59 Invocation sites collapse to profile pointers (v2.3)
**Decision:** ~40 "Caveman ULTRA mode" phrases rewrite to a one-line profile pointer
per prompt — subagents `compression: internal (.claude/ref/compression.md).`, commands
`compression: user (…)`; AGENTS.md declares the `user` directive; the SessionStart hook
reminder references the profile system.
**Rejected:** outright deletion (breaks coverage — no inheritance); keeping full phrases
(redundant, drift-prone).

### 5.60 Positive artifact exemption as structural gate (v2.3)
**Decision:** exact-output artifacts (RED harness assertions, spec-author contract
output, fixtures, emitted Playwright, `# spec:`/`// spec:` citations, quoted errors)
are exempted from compression via a positive structural gate declared in the
`spec-author`, `test-author`, and `e2e-runner` prompts — not a rule inside the
reference file. Compression is always-on, so exemption must be explicit at the artifact
boundary.
**Rejected:** exemption as a rule in the reference file (mixes concerns); inline prose
per agent (non-structural, unverifiable).

### 5.61 Model-invoked compression triggers killed (v2.3)
**Decision:** the skill description triggers ("caveman mode", "be brief", `/caveman`)
are deleted. Compression exists only as an always-on directive + profile pointers.
Mandatory behavior is never model-invoked.

### 5.62 grill-me vendored as sole source (v2.3)
**Decision:** the vendored `grill-me` copy is authoritative; the "global-authoritative
if installed" resolution rule is dropped entirely (it existed to serve two external
skills; caveman's internalization leaves one consumer, which does not justify a
resolution mechanism). §5.8 is superseded by this.
**Rejected:** keeping the resolution rule for one consumer (dead mechanism).

### 5.63 User freedom = composition, not enforcement (v2.3)
**Decision:** users choose use case and modules; every installed gate stays HARD. No
config to soften gates to warnings. Non-agent-behavior files (templates, scaffold,
infra scripts) must be use-case-agnostic.
**Rejected:** gate-softening config (a soft gate is a discipline rule; discipline rules
are ruled out — "worry-free or fail hard").

### 5.64 LCD core + matured practice as preinstalled knowledge docs (v2.3)
**Decision:** the core ships nothing use-case-specific. Matured practices become
preinstalled knowledge docs — `knowledge/webapp.md`, `knowledge/azure.md` — consulted
by `researcher` (new STEP 0.5) at RESEARCH when the declared use case matches. Branch-
only reference via pointer, loaded only when the branch triggers; reuses existing
machinery (researcher already consults `research/INDEX.md` + KB snapshot). Selection is
a deterministic table in `commands.src/overview.md`, recorded as OVERVIEW
`knowledge_docs:` — never researcher-inferred (§5.66).
**Rejected:** project-type scaffolds at install (designs N scaffolds upfront, guesses at
demand); pure LCD without knowledge docs (guts the "ready-made" value users praised).

### 5.65 Adaptive loop: RESEARCH binds E2E_KIND / DEPLOY_KIND (v2.3)
**Decision:** the TDD APPLICABILITY check at RESEARCH is extended to bind two further
per-phase values, same idiom as `TDD_PHASE`: `E2E_KIND` (browser via Playwright, CLI
invocation, HTTP, library public API — generalizes v2.2's browser-specific boundary
concept to outer-boundary) and, on the final phase, `DEPLOY_KIND` confirmation. "Last
phase always includes deployment" is re-worded to "last phase always completes
DEPLOY_KIND."
**Realization (ordering split):** §5.65's literal "RESEARCH sets the flags" cannot hold
for `INFRA_NEEDED` because `/phase` PRE-FLIGHT (which blocks on Phase 0) runs BEFORE
RESEARCH. Resolved by splitting DECLARATION from BINDING: the project-level facts
(`project_type`, `infra_needed`, `e2e_kind` baseline, `deploy_kind`, `knowledge_docs`)
are declared at `/overview` and recorded in OVERVIEW.md (same idiom as `has_frontend`),
where PRE-FLIGHT can read them; RESEARCH does the per-phase binding (effective
`E2E_KIND` = browser iff frontend phase else baseline; `DEPLOY_KIND` re-confirm on final
phase).
**Realization (browser-only dispatch):** `e2e-runner` stays a Playwright emitter,
dispatched only when the bound `E2E_KIND` is `browser`; for cli/http/library-api the
generalized rule 13 is satisfied by `test-author`'s real-mode boundary suite against the
outer surface, with its transcript captured as evidence — no separate shipped-artifact
runner.
**Rejected:** dropping deploy/E2E from the core loop (weakens the completeness
guarantee); a universal outer-boundary emitter for all kinds (more prompt surface than
the real-mode suite already provides).

### 5.66 Project type declared at /overview (v2.3)
**Decision:** the `/overview` grill asks `project_type` (web app / desktop app / script
/ library / other). The answer is recorded in `docs/OVERVIEW.md` (alongside
`has_frontend` + frontend root). `researcher` reads it to select knowledge docs;
RESEARCH uses it (via the derived flags) to shape the loop.
**Rejected:** researcher infers type from description (a model-invoked trigger for
mandatory behavior — the pattern §5.61 kills).

### 5.67 Minimal core cut line (v2.3)
**Decision:** default install ships `AGENTS.md`, hooks, slash commands, agent prompts,
the doc system (STATE/ISSUES/synthesizer/snapshots), knowledge docs, gate scripts. Cut
from default install: `playwright.config.ts`, `e2e/`, `docker-compose.test.yml`,
`scripts/e2e-stack.sh`, `scripts/auth-setup.sh`. Cut items are NOT deleted from the kit
— they are embedded as fenced templates in `knowledge/webapp.md` / `knowledge/azure.md`
and materialized per-project on demand (then user-owned, like `fixtures/`). Chosen over
a non-installed templates dir, which would need new manifest/setup.sh gating machinery
right after the Cursor gating was removed.
**Retention constraint (user feedback #4):** doc auto-update + slash commands survive
untouched in the minimal core.
**Rejected:** interactive module picker at install (defer until real packs exist).

### 5.68 Infra-provisioner conditional; Azure → knowledge doc (v2.3)
**Decision:** `infra-provisioner` stays in the kit, prompt generalized (Azure specifics
— Bicep, `az`, Entra/MSAL, THB costs, Key Vault — move to `knowledge/azure.md`). The
`infra_needed` flag (declared at `/overview`: application types → true; script/library →
false) gates Phase 0 dispatch. The SessionStart Azure reminder line and `auth-setup.sh`
leave core; the Azure knowledge doc reintroduces the auth ritual (materializable
`scripts/auth-setup.sh` template) when Azure is in play, and the project's liveness
command is recorded in `docs/INFRA.md ## AUTH` so `/phase` PRE-FLIGHT stays generic.
Old hard rule 10 (Azure auth once-per-session) moves to `knowledge/azure.md`; its slot
is repurposed for the new deterministic-flags rule (zero renumbering — all `hard rule N`
cross-references keep their numbers).
**Rejected:** dropping infra-provisioner from core (loses mandatory coverage for
application use cases); keeping the Azure-fitted prompt (violates §5.63); renumbering the
hard rules (needless churn — rules 1–19 are contiguous, the slot repurposes cleanly).

### 5.69 Cursor hard drop (v2.3)
**Decision:** delete `.cursor/hooks.json`, `.cursor/commands/` generation, `.cursor/
rules/` pointer, Cursor sections in README/docs, `cursor-session-start.sh`, and the
dual-tool wiring in `setup.sh` + `create-anpunkit` (the whole `--tools`/`--add-tool`/
`anpunkit-tools.json` tool-selection machinery, dead once one tool remains). README
states "Claude Code only." A deliberate reversal of the v2.x Cursor-parity investment
(v2.2 explicitly maintained parity): maintenance cost exceeds demand per user feedback.
§5.32 (installer tool selection) is reversed by this.
**Rejected:** soft drop with a "portable if you re-wire" note (half-promise, support
burden).

### 5.70 spec-author / test-author tool grants settled (v2.3, v2.2 carry-over)
**Decision:** `spec-author` and `test-author` are granted `Read, Grep, Glob, Write,
Bash` — deliberately NO `Edit`. `spec-author` authors fresh spec rows and fixtures
(Write), never patches source; at SPEC REVIEW a "wrong expected" correction is applied
by the ORCHESTRATOR patching the fixture directly (`phase.md §3`), not by re-granting
`spec-author` edit rights. Recorded here to close the v2.2 carry-over.
**Rejected:** granting `Edit` for in-place fixture patches (blurs author ≠ implementer,
§5.53; the orchestrator-patch path already covers it).

### 5.71 fixtures/ committed, never gitignored (v2.3, v2.2 carry-over)
**Decision:** `fixtures/<case-id>-{input,expected,ui}.json` are COMMITTED — they are the
behavioral contract that both the spec row and the generated test harness load
(transcription is structural, not honor-system). Deliberate contrast with
`docs/evidence/`, `docs/research/*.md`, `.env.test`, `docs/.snapshots/`, and
`docs/.kb-snapshot.md`, which ARE gitignored. `.gitignore` therefore must NOT list
`fixtures/`. Recorded here to close the v2.2 carry-over.
**Rejected:** gitignoring fixtures (would break the contract-load guarantee — the test
would have no expected values to assert against on a fresh checkout).

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

### v2.2 additions to the inventory

```
.claude/agents/spec-author.md      NEW — fills per-phase spec + fixtures (Opus); author ≠ implementer
scripts/spec-staleness.sh          NEW — stamp/check the spec header hash vs PLAN+DATAFLOW (rule 17)
scripts/spec-conformance.sh        NEW — no-TBD + every case-id cited by a boundary test (rule 18)
tests/helpers/spec-assert.py       NEW — kit comparator (matcher tokens), Python
tests/helpers/spec-assert.ts       NEW — kit comparator (matcher tokens), TS/JS
docs/spec-phase-<n>.md             NEW per-project — skeleton at /overview, filled per phase (committed)
fixtures/<case-id>-*.json          NEW per-project — shared by spec row + generated harness (committed)
```

Role deltas: `planner` also writes skeleton specs; `test-author` + `e2e-runner`
become harness EMITTERS (generate from spec rows, author no assertions);
`implementer` FILL reads the filled spec as its contract. `.gitattributes` gains
`*.py text eol=lf` (the kit now ships a Python comparator). REMOVED: the v2.1 human
TEST REVIEW gate + the `docs/test-plan-phase-<n>.md` artifact.

### v2.3 changes to the inventory

```
.claude/ref/compression.md         NEW — kit-native compression profiles (user, internal); single source
knowledge/webapp.md                NEW — matured web-app practice + browser-E2E stack templates
knowledge/azure.md                 NEW — matured Azure practice + auth-ritual/provisioning templates
.claude/skills/caveman/            REMOVED — internalized to .claude/ref/compression.md
.cursor/                           REMOVED — hooks.json, rules/anpunkit.md, commands/ (Cursor dropped, §5.69)
.claude/hooks/cursor-session-start.sh  REMOVED — Cursor JSON-envelope wrapper
.claude/anpunkit-tools.json        REMOVED (per-project) — installer tool-selection machinery gone
playwright.config.ts               CUT from default install — now a template in knowledge/webapp.md
e2e/global-setup.ts                CUT — template in knowledge/webapp.md
docker-compose.test.yml            CUT — template in knowledge/webapp.md
scripts/e2e-stack.sh               CUT — template in knowledge/webapp.md
scripts/auth-setup.sh              CUT — template in knowledge/azure.md
```

Role deltas (v2.3): `researcher` gains STEP 0.5 (consult OVERVIEW `knowledge_docs`
before web search); `infra-provisioner` generalized (cloud specifics → knowledge/
azure.md, dispatched only when `infra_needed`); `planner` Phase-0-conditional +
`deploy_kind` completion; `e2e-runner` = browser E2E_KIND emitter. `commands.src/`
now generates only `.claude/commands/`. Hard rule 10 repurposed (Azure auth →
knowledge/azure.md; new slot = deterministic flags); rules 8/13/16 generalized in
place; rules stay 1–19 contiguous.

## 7. How each original problem maps to its fix

| Problem | Fix |
|---|---|
| 1 miss issue log | SessionStart hook injects open ISSUES.md every session |
| 2 manual navigation | SessionStart hook injects STATE.md + git + research INDEX |
| 3 stuck too long | warn at 2; first hard-stop at 3 stops and asks; `/unstuck` for deep re-research |
| 4 context rot in debug | `debugger` isolated context + writes noise to file |
| 5 want orchestration | 8 scoped subagents; `/phase` orchestrates them |
| 6 handoff bloat | `synthesizer` + PreCompact hook; HISTORY.md for long log |
| 7 cloud auth friction + infra ad-hoc | INFRA.md `## AUTH` liveness ritual (Azure: `knowledge/azure.md`) + `infra-provisioner` Phase 0 when `infra_needed` |
| 8 re-discovering same gotchas across projects | KB snapshot at session start; researcher checks before web; `/store-wisdom` promotes findings |

---

## 8. Known gaps & template placeholders

1. `docker-compose.test.yml` — build contexts and ports are TEMPLATE values.
   (v2.3: now a fenced template in `knowledge/webapp.md`, materialized per project.)
2. `e2e/global-setup.ts` — MSAL cache-key shape is a stub; adjust for app's
   `@azure/msal-browser` version/config. (v2.3: template in `knowledge/webapp.md`.)
3. *(resolved v2.3, §5.57)* caveman is now kit-native and single-source
   (`.claude/ref/compression.md`) — there is no vendored-vs-user-variant divergence.
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
6. The behavioral contract is the human-approved SPEC; tests are GENERATED from its
   case rows against shared fixtures (author ≠ implementer). This is the v2.2
   unbiased-test guarantee — it replaces v2.1's "tests written blind" (the spec
   fixtures are authored before code, so the contract can't be shaped to an impl).
   (Non-TDD phases keep blind-from-acceptance tests — no spec to drive them.)
7. Boundary auth uses a dedicated headless test credential; never script an
   interactive login UI (Microsoft/Entra specifics: `knowledge/azure.md`). (v2.3)
8. Fail loud, never silent — especially hook wiring.
9. Honest failure classification — environment issues never burn the debug budget.
10. Infra is Phase 0 when `INFRA_NEEDED`: provisioned once, reviewed before apply,
    recorded in INFRA.md. (v2.3: conditional on the declared use case.)
11. Plan before code: design-research + double grill before OVERVIEW.md is written.
    The planner must never design phases against unverified assumptions.
12. The last phase always completes `DEPLOY_KIND` — cloud deploy, package publish, or
    verified install/run — never omitted (only `none` with a recorded reason), never a
    separate phase. (v2.3: generalized from "deployment".)
13. The shared KB is human-gated at both ends: you approve before push (/store-wisdom),
    and findings are static within a session (KB snapshot). The KB never writes itself.
