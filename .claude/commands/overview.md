---
description: Bootstrap a new project. Runs design-research, double grill, and planning. Run once per project.
---

Caveman ULTRA mode.

Recommended: run from plan mode (Shift+Tab). Planning agents are read-only by
tool grant; plan mode adds a read-only gate on the main session too. Optional.

Goal: stand up a fresh project workspace with a well-grounded plan.

---

## Steps

### Round 1 — Initial grill

1. Run the `grill-me` skill to interrogate me. Goal: understand initial scope.
   Cover: project purpose, success criteria, external services, Azure services
   needed (type + sizing), region, deployment target (Azure or local for E2E),
   known constraints, unknowns.
   Do not stop early. Do not write OVERVIEW.md yet.

Store the round-1 answers as working context — do NOT write OVERVIEW.md yet.

---

### Design research

2. Extract DESIGN TOPICS from the round-1 answers. These are things we need
   to verify before planning:
   - Each external service mentioned: what does it support at the relevant tier?
     Quotas, rate limits, known gaps?
   - Azure services: any sizing or SKU constraints relevant to the use case?
   - Auth patterns: any MSAL/Entra constraints for this scenario?
   - Any other architectural assumption in the round-1 answers worth verifying.

3. Dispatch `researcher` in DESIGN mode with the DESIGN TOPICS list.
   It returns a terse summary + file paths. Read the design-<slug>.md files
   only if needed.

---

### Round 2 — Research-informed re-grill

4. Run `grill-me` again — a second focused pass. Seed it with:
   - The round-1 answers (already established — do not re-ask these)
   - The design-research key findings and new questions raised

   The re-grill asks whatever it needs to build complete understanding. It is
   not limited to "gaps from research" — research context makes new questions
   relevant even if it found no blockers. Do not re-ask what round 1 already
   established clearly.

---

### Write OVERVIEW.md

5. Write docs/OVERVIEW.md from the COMBINED output of round-1 + design-research
   + round-2. Include:
   - Project purpose and success criteria
   - Scope and constraints (informed by research findings)
   - External services with confirmed capabilities/limits
   - "Azure services" section: every service with expected SKU
   - Deployment target (azure-deployed or local-docker for E2E)
   - Known risks / open questions (if any remain)

   OVERVIEW.md is written HERE — after the re-grill, not before.

---

### Plan

6. Hand OVERVIEW.md + design-research findings to the `planner` subagent.
   PLAN.md MUST:
   - Start with Phase 0 (infra setup) as the first entry (always).
   - End with a final code phase that contains the deploy task block.

7. Create docs/STATE.md:
```

# STATE

phase: 0 (pending)
completed: project bootstrapped — design research done, double grill done
next: run /infra to provision Azure infrastructure
blocker: none

```
8. Create docs/ISSUES.md with header `# Issues` and `## Archived` section.

9. Create empty docs/HISTORY.md.

10. Create docs/INFRA.md from the template (populated by /infra).

11. Create docs/ENDPOINTS.md:
 ```
 # Endpoints — <project name>
 > Maintained by implementer. Updated each phase.
 > Base URL: (populated after deployment phase)
 ```

Then stop and show me PLAN.md for approval before any phase starts.

Remind me: "Run `/infra` next to provision the Azure environment (Phase 0)
before starting Phase 1."
