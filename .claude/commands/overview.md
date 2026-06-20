---
description: Bootstrap a new project. Runs design-research, research review, double grill (incl. data/state flow), datasource-understanding baseline, and planning. Run once per project.
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
   known constraints, unknowns. ALSO establish:
   - **has_frontend**: is there a browser-facing UI? If yes, what is the frontend
     root path (e.g. `src/web/`, `app/`)? This drives the mandatory-E2E path match.
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
   - Each external DATASOURCE: its DATA UNDERSTANDING (see step 4).
   - Any other architectural assumption in the round-1 answers worth verifying.

3. Dispatch `researcher` in DESIGN mode with the DESIGN TOPICS list.
   It returns a terse summary + file paths. For every external datasource it
   drafts a DATA UNDERSTANDING to `docs/research/datasource-<name>.md`:
   grain (one row = what?), the fields likely under test with their meaning and
   real-world nullability/range, a sample-fixture shape, and the assumption that
   if wrong makes a test meaningless. Read the design-<slug>.md files only if needed.

---

### RESEARCH REVIEW (v2.1 — read-and-confirm, not a grill)

4. Surface the design-research findings to me DIRECTLY, phrased as FALSIFIABLE
   CLAIMS about my systems — not a passive findings dump. For example:
   "I understand your Tableau extract refreshes nightly and the API is read-only;
   the `orders` grain is one row per line-item; `status` is never null in practice."
   For each external datasource, present its drafted DATA UNDERSTANDING for me to
   confirm or correct. Then:
   - Minor corrections -> fold forward as seed context for round-2 grill.
   - A MATERIAL error (wrong service tier, wrong data model, wrong grain) ->
     re-dispatch `researcher` with the correction, then re-present. Do not carry
     a known-wrong research file into grill or OVERVIEW.md.
   A confirmed datasource understanding is recorded as the BASELINE in its
   `datasource-<name>.md`. (Per-phase delta-confirms happen later in `/phase`.)

---

### Round 2 — Research-informed re-grill

5. Run `grill-me` again — a second focused pass. Seed it with:
   - The round-1 answers (already established — do not re-ask these)
   - The design-research key findings and new questions raised
   - The RESEARCH REVIEW corrections

   This pass MUST explicitly cover DATA STRUCTURE and DATAFLOW, especially the
   STATE FLOW of each key object: what are the core entities, what states does
   each move through, what transition triggers each change, who writes it, and
   does any state map to an external system. The re-grill asks whatever else it
   needs for complete understanding. Do not re-ask what round 1 established.

---

### Write OVERVIEW.md + DATAFLOW.md

6. Write docs/OVERVIEW.md from the COMBINED output of round-1 + design-research
   + research review + round-2. Include:
   - Project purpose and success criteria
   - Scope and constraints (informed by research findings)
   - External services with confirmed capabilities/limits
   - "Azure services" section: every service with expected SKU
   - Deployment target (azure-deployed or local-docker for E2E)
   - `has_frontend: true|false` and, if true, the frontend root path
   - Known risks / open questions (if any remain)

   OVERVIEW.md is written HERE — after the re-grill, not before.

7. Write docs/DATAFLOW.md — a state-transition table per key object, driven by the
   round-2 data/state-flow grill. The data-side analogue of ENDPOINTS.md. Columns:
 ```
 # Dataflow — <project name>
 > Maintained from /overview; updated each phase that changes an object lifecycle.
 > Each transition row is one testable unit (drives the CLOSE coverage gate).

 | object | states | transition (from→to) | trigger | who writes | external system |
 |--------|--------|----------------------|---------|------------|-----------------|
 | Order  | draft,submitted,fulfilled | draft→submitted | POST /orders/submit | order-svc | — |
 ```
   Any row whose `external system` is populated ties to a `datasource-<name>.md`.

---

### Plan

8. Hand OVERVIEW.md + DATAFLOW.md + design-research findings to the `planner`
   subagent. PLAN.md MUST:
   - Start with Phase 0 (infra setup) as the first entry (always).
   - End with a final code phase that contains the deploy task block.
   - For any phase whose `changes` touch the frontend root: include ≥1
     UI-existence acceptance criterion naming the specific user-visible
     interactive element the phase introduces (not "page renders 200").
   - Map each phase to the DATAFLOW transitions it is expected to make reachable.

9. Create docs/STATE.md:
```

# STATE

phase: 0 (pending)
completed: project bootstrapped — design research, research review, double grill (incl. data/state flow) done
next: run /infra to provision Azure infrastructure
blocker: none

```
10. Create docs/ISSUES.md with header `# Issues` and `## Archived` section.

11. Create empty docs/HISTORY.md.

12. Create docs/INFRA.md from the template (populated by /infra).

13. Create docs/ENDPOINTS.md:
 ```
 # Endpoints — <project name>
 > Maintained by implementer. Updated each phase.
 > Base URL: (populated after deployment phase)
 ```

Then stop and show me PLAN.md + DATAFLOW.md for approval before any phase starts.

Remind me: "Run `/infra` next to provision the Azure environment (Phase 0) and
run the one-time AUTH PROOF before starting Phase 1."
