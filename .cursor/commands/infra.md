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
   Then run AUTH PROOF (below) before declaring Phase 0 complete.

---

## AUTH PROOF (one-time, hard rule 16)

Runs after a successful PROVISION (and on demand via `/infra auth-proof`). Proves
every credential the project's real tests will use is reusable WITHOUT interaction.
"Reusable" is defined falsifiably: obtainable headlessly TWICE IN A ROW.

1. Enumerate the credentials in scope: the Entra/MSAL app login, plus every
   external datasource credential referenced in docs/DATAFLOW.md (external rows)
   and docs/ENDPOINTS.md (auth column) — Azure SQL, Tableau, etc.

2. Dispatch `infra-provisioner` to run, for EACH credential, a headless obtain
   twice in a row: first call primes (token fetch / connect), second call must
   succeed from cache/refresh with ZERO prompts. The Microsoft login UI is never
   driven (ROPC + dedicated MFA-excluded test account; hard rule 8).

3. Result:
   - All credentials pass twice headlessly -> write `AUTH PROOF: PASS <timestamp>`
     to docs/INFRA.md with the per-credential list. Phase 0 may complete.
   - Any credential prompts or fails the second obtain -> NOT reusable. Write
     `AUTH PROOF: FAIL` + which credential, STOP, tell me what to fix. Phase 0 is
     not complete until the proof passes.

---

## VERIFY flow

1. Check INFRA.md exists. If missing: tell me to run `/infra provision` first.
2. Dispatch `infra-provisioner` VERIFY mode.
3. Return drift report. If the AUTH PROOF marker is missing or stale, re-run AUTH PROOF.

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
