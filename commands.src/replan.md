---
description: Revise docs/PLAN.md when it no longer matches reality — add, cut, split, merge, or reorder phases.
argument-hint: [what changed about the plan]
---

Caveman ULTRA mode.

Recommended: run from plan mode (Shift+Tab). Optional; the command stops for
your approval regardless.

Use when PLAN.md no longer matches reality. Change: $ARGUMENTS

---

## Steps

1. PRE-FLIGHT. Read docs/STATE.md and docs/PLAN.md.
   - Phase in progress -> tell me which. Ask: revise around it, or is it the
     thing being changed? Do not silently rewrite a mid-execution phase.
   - Done phases are FROZEN. /replan never edits or reorders done phases.
   - Phase 0 (infra) is ALWAYS frozen once done.

2. DESIGN RESEARCH CHECK. Scan $ARGUMENTS for signals that design research
   is warranted before re-planning:
   - A new external service is mentioned (Stripe, Twilio, a new Azure service, etc.)
   - The change involves architecture (a new integration pattern, auth change, etc.)
   - A service tier or quota change is implied

   If ANY of these signals are present: dispatch `researcher` in DESIGN mode
   with the specific new service/pattern as the DESIGN TOPICS list. Show me the
   key findings before proceeding to step 3.

   If none: proceed directly to step 3 (impl-research may still be dispatched
   in step 3 for non-trivial changes per the original logic).

3. IMPL RESEARCH if needed. If the change is non-trivial but design research
   was not needed, dispatch `researcher` in IMPL mode to ground the re-plan
   in facts.

4. RE-PLAN. Dispatch `planner` with the change + current PLAN.md. It must:
   - Keep done phases untouched.
   - Insert / cut / split / merge / reorder only PENDING phases.
   - Place new phases in correct DEPENDENCY order.
   - Keep every phase a vertical slice with its own acceptance spec.
   - Ensure the LAST pending phase still contains the deploy task block.
   - Renumber pending phases if needed; update STATE.md `phase:` pointer.

5. RECONCILE THE REGRESSION CORPUS (scoped to `tests/regression/`):
   - A CUT phase -> retire its regression tests.
   - A MERGE -> consolidate the merged phases' regression tests.
   - A REORDER -> keep the tests as-is (contracts are phase-independent).
   Do NOT touch phase-local `tests/phase-<n>/` here beyond renumbering dirs.
   After reconciling, run `scripts/regression.sh --real` to confirm the
   reconciled corpus still passes against live services. A failure -> surface it
   and stop before approval.

6. SHOW ME the revised phase list + the regression-corpus changes, and STOP for
   approval.

7. ARCHITECTURE SELF-CHECK: re-planning is not normally a kit-architecture
   change. Only run /log-decision if the workflow itself changed (rare).

Report what changed: phases added / cut / split / reordered, and regression
tests retired / consolidated.
