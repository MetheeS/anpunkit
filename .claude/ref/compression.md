# Compression profiles — kit-native, single source, always-on

> **What this file is.** The ONE place compression rules live (anti-drift
> invariant). `AGENTS.md` declares profile `user` for all human-facing output;
> every subagent prompt declares profile `internal` with a one-line pointer
> here. Nothing restates these rules.
>
> **Never model-invoked.** This is not a skill. There is no trigger phrase, no
> description matcher, no `/command`. Compression is mandatory behavior wired
> by pointers, not invoked by pattern-match (v2.3, §5.61).

## Shared rules (both profiles)

Respond terse. All technical substance stay. Only fluff die.

Drop: articles (a/an/the), filler (just/really/basically/actually/simply),
pleasantries (sure/certainly/of course/happy to), hedging. Fragments OK. Short
synonyms (big not extensive, fix not "implement a solution for"). Abbreviate
common terms (DB/auth/config/req/res/fn/impl). Strip conjunctions. Use arrows
for causality (X -> Y). One word when one word enough.

Technical terms stay exact. Code blocks unchanged. Errors quoted exact.

Pattern: `[thing] [action] [reason]. [next step].`

Not: "Sure! I'd be happy to help you with that. The issue you're experiencing is likely caused by..."
Yes: "Bug in auth middleware. Token expiry check use `<` not `<=`. Fix:"

## Profile: `user`

Human-facing output — the orchestrator / main session, all slash commands.

Shared rules apply, plus the **Auto-Clarity exception**: expand to full clarity
temporarily for security warnings, irreversible-action confirmations,
multi-step sequences where fragment order risks misread, and clarification
requests or repeated questions. Resume compressed after.

## Profile: `internal`

Agent-to-agent output — subagent returns, dispatch text, summaries between
roles. Shared rules apply, harder: no clarity exception (no human reads this
mid-flight). Return-format blocks are structure — keep the structure, fill the
fields tersely.

## Exemptions are structural, not here

Exact-output artifacts — fixture JSON, spec table rows, matcher tokens,
emitted test/harness code, `# spec:` citations, quoted errors — are exempted
by explicit ARTIFACT EXEMPTION gates declared in the emitter prompts
(`spec-author`, `test-author`, `e2e-runner`), never by a rule in this file
(§5.60). Compression governs prose; contract material is byte-precise.

## Persistence

Active every response, both profiles. No drift back to filler over long
sessions. No toggle phrases exist — there is nothing to switch off.
