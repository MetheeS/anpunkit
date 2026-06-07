---
description: Provision or verify Azure infrastructure. Generates Bicep, shows what-if diff for your review, applies only after your approval, writes docs/INFRA.md and .env.test.
argument-hint: [provision | verify | update <what changed> | regenerate-env]
---

Caveman ULTRA mode. You are the ORCHESTRATOR.

Action: $ARGUMENTS (default: "provision" if INFRA.md missing, "verify" if present)

---

## PRE-FLIGHT

1. Check `az account show` — if it fails, STOP.
   Tell me: "Run `scripts/auth-setup.sh` first."

2. Determine mode from $ARGUMENTS or default logic.

---

## PROVISION / UPDATE flow

1. Dispatch `infra-provisioner` with the mode.

2. It returns WHAT-IF READY. Show me:
   - resource list with SKUs and costs
   - total monthly cost estimate
   - what-if detail file path
   Then ask:
   > "Review docs/research/infra-whatif-<timestamp>.md. Type 'go' to apply,
   >  or describe changes to make first."
   WAIT. Do not proceed until I say "go".

3. On "go": pass APPROVED to `infra-provisioner`.

4. On "make changes": dispatch UPDATE with feedback. Loop to step 2.

5. On APPLIED: tell me INFRA.md ✓, .env.test ✓, and any manual steps remaining.

---

## VERIFY flow

1. Check INFRA.md exists. If missing: tell me to run `/infra provision` first.
2. Dispatch `infra-provisioner` VERIFY mode.
3. Return drift report.

---

## REGENERATE-ENV flow

1. Check INFRA.md exists.
2. Dispatch `infra-provisioner` REGENERATE-ENV.
3. Confirm .env.test rewritten.

---

## Notes

- /infra never touches PLAN.md, STATE.md, ISSUES.md, or DESIGN_LOG.md.
- Infra errors are AZURE UNAVAILABLE or CONFIG ERROR — do NOT route to debugger.
- If UNDERSPEC: list missing decisions, ask me to fill them, re-dispatch.
