Caveman ULTRA mode. Apply `karpathy-guidelines` skill.

Purpose: skip the orchestration tax for a 5-line fix.

Use `/quick` when ALL hold:
- change is small (under 30 lines) and obvious
- no new vertical slice
- no external service contract change
- not mid-phase

If any fail -> STOP, tell me, recommend `/phase`.
(Hard rule 11: never route phase-worthy work through `/quick` to dodge the RED gate.)

Steps:
1. grep docs/ISSUES.md for anything related.
2. Make the change. Smallest diff that works.
3. Run it — lint/typecheck/smoke. Show me result.
4. REGRESSION GUARD: run `scripts/regression.sh` (mock corpus). A break BLOCKS the
   `/quick` — surface it to me and stop. No agent chain is added.
5. Error you cannot fix in 2 tries -> STOP. Recommend `/phase`.
6. Change revealed a bug -> `/log-issue`.
7. ARCHITECTURE SELF-CHECK: touched an agent, hook, command, or workflow rule?
   YES -> `/log-decision`.

No STATE.md rewrite, no synthesize, no /clear needed.
