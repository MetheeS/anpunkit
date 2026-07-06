@AGENTS.md

# CLAUDE.md — Claude Code native wiring (thin shim)

> This file restates NO methodology. Every rule, role, procedure, and ritual
> lives in `AGENTS.md`, imported above via the bare `@AGENTS.md` line (the first
> non-comment line — `setup.sh` VERIFY checks it is bare, top-level, and
> unfenced). This shim only maps the methodology onto Claude Code's native
> mechanisms.

## Subagent roster

The roles defined in AGENTS.md map to these Claude Code subagent files:

|Role              |Definition file                       |Model tier|
|------------------|--------------------------------------|----------|
|researcher        |`.claude/agents/researcher.md`        |haiku     |
|planner           |`.claude/agents/planner.md`           |opus      |
|infra-provisioner |`.claude/agents/infra-provisioner.md` |opus      |
|spec-author       |`.claude/agents/spec-author.md`       |opus      |
|implementer       |`.claude/agents/implementer.md`       |opus      |
|test-author       |`.claude/agents/test-author.md`       |opus      |
|e2e-runner        |`.claude/agents/e2e-runner.md`        |opus      |
|debugger          |`.claude/agents/debugger.md`          |opus      |
|synthesizer       |`.claude/agents/synthesizer.md`       |haiku     |

## Hooks automate the AGENTS.md rituals

On Claude Code, do NOT run the SESSION-OPEN or COMPRESS rituals by hand — the
hooks (wired in `.claude/settings.json`) perform them:

- **SessionStart** (`.claude/hooks/session-start.sh`) automates SESSION-OPEN:
  auto session-open + KB pull + STATE/ISSUES/research/infra injection into context.
- **PreCompact** (`.claude/hooks/pre-compact.sh`) automates COMPRESS: snapshots the
  live position before compaction.
- **SubagentStop** (`.claude/hooks/subagent-stop.sh`) writes a subagent trace.

## /clear keeps hooks

`/clear` does not drop hooks — the wiring lives in `settings.json`, not in
context. After `/clear`, SessionStart fires again and re-injects state.

## Skills resolution

- `karpathy-guidelines`, `grill-me` — kit-owned (`.claude/skills/…`), the sole
  source. No "global-authoritative if installed" resolution.
- Compression is kit-native (`.claude/ref/compression.md`), NOT a skill — always
  on, single source, never model-invoked.

## Platform notes

- **Windows / Git Bash.** Hooks are bash scripts. Hook commands use a BARE `bash`
  prefix (`bash .claude/hooks/session-start.sh`) — never an explicit `bash.exe`
  path (triggers a Claude Code argument-splitter bug). `.gitattributes` pins all
  `.sh` files to LF. WSL runs the kit as-is.
- **Plan mode.** Run planning-heavy commands (`/overview`, `/replan`) from plan
  mode (Shift+Tab).

## Silent injection (Claude Code 2.1.x) + fresh-session test

On Claude Code 2.1.x the SessionStart injection may be silent (no visible banner).
That is normal. To verify hooks are live, in a fresh session ask:

> What does my STATE.md say, and how many open issues are in ISSUES.md?

A correct answer without Claude reading any file = hooks working.
