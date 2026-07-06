# knowledge/webapp.md — matured web-app practice (preinstalled)

> **What this file is.** Use-case knowledge for browser-facing web apps,
> consulted by `researcher` (STEP 0.5) when `knowledge/webapp.md` appears in
> the `knowledge_docs:` list of `docs/OVERVIEW.md`. Selection is deterministic
> — declared at `/overview`, never inferred (hard rule 10).
>
> **Templates below are materialized per-project** — copied to the stated path
> the first time the phase work needs them. Once materialized they are
> user-owned project files: adjust freely, the kit never overwrites them.

## Browser boundary practice (E2E_KIND: browser)

- `ui` spec cases carry a `fixtures/<case-id>-ui.json` descriptor with a
  closed, kit-versioned assert vocabulary: `visible`, `text-equals`,
  `enabled`, `count`. `e2e-runner` EMITS Playwright specs from descriptors —
  it never authors blind from prose.
- Each emitted spec block carries a `// spec: <case-id>` citation
  (`spec-conformance.sh` checks it).
- EVIDENCE (hard rule 13): at each UI-existence assertion, capture a
  screenshot regardless of pass/fail to
  `docs/evidence/e2e-phase-<n>/<case-id>-<element-slug>.png` — one shot per
  asserted element, on green as well as red.
- `ui` cases have NO mock mirror — the browser IS the boundary.

## E2E stack ritual

Two target modes, recorded in `docs/INFRA.md`:

- **azure-deployed** (`E2E_STACK_EXTERNAL=1` in `.env.test`): tests hit the
  deployed app; `e2e-stack.sh up` only health-checks reachability.
- **local-docker**: `e2e-stack.sh up` builds + starts the compose stack and
  polls health.

Sequence, always: `bash scripts/e2e-stack.sh up` -> `npx playwright test` ->
`bash scripts/e2e-stack.sh down`. Stack didn't come up -> classify
**STACK NOT READY** (not a bug; no debug budget).

## Web deploy ritual (DEPLOY_KIND: cloud-deploy)

- Deploy task lives in the final phase (DEPLOY_KIND completion, hard rules).
- After deploy: record the deployed base URL in `docs/INFRA.md`
  (`## Deployed base URL`) and confirm `docs/ENDPOINTS.md` entries resolve
  against it; run a `/health` (or equivalent) check before calling it done.

## .gitignore lines a materialized stack needs

```
e2e/.auth/
playwright-report/
test-results/
```

---

## Templates

### `playwright.config.ts` — materialize to project root

```ts
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  globalSetup: './e2e/global-setup.ts',
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers: 1,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: process.env.E2E_BASE_URL || 'http://localhost:8080',
    storageState: 'e2e/.auth/state.json',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    actionTimeout: 15_000,
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
  webServer: process.env.E2E_STACK_EXTERNAL ? undefined : {
    command: 'bash scripts/e2e-stack.sh up',
    url: process.env.E2E_BASE_URL || 'http://localhost:8080',
    timeout: 180_000,
    reuseExistingServer: !process.env.CI,
  },
});
```

### `e2e/global-setup.ts` — materialize to `e2e/`

Entra ID ROPC token injection (Azure/MSAL apps — see `knowledge/azure.md` for
the auth practice). Known gap: the localStorage keys (`e2e.access_token`,
`e2e.id_token`) are a stub convention — align them with your app's real MSAL
cache keys when materializing.

```ts
// e2e/global-setup.ts
import { chromium } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';

const AUTH_DIR = path.join(__dirname, '.auth');
const STATE = path.join(AUTH_DIR, 'state.json');

async function fetchRopcToken() {
  const tenant = reqEnv('E2E_TENANT_ID');
  const body = new URLSearchParams({
    grant_type: 'password',
    client_id: reqEnv('E2E_CLIENT_ID'),
    username: reqEnv('E2E_TEST_USER'),
    password: reqEnv('E2E_TEST_PASSWORD'),
    scope: `openid profile ${reqEnv('E2E_SCOPE')}`,
  });
  const url = `https://login.microsoftonline.com/${tenant}/oauth2/v2.0/token`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });
  if (!res.ok) {
    const txt = await res.text();
    throw new Error(
      `ROPC token fetch failed (${res.status}). ` +
      `Check: ROPC enabled on app registration, test user exists, ` +
      `MFA excluded via Conditional Access. Response: ${txt}`
    );
  }
  return res.json() as Promise<{ access_token: string; id_token: string; expires_in: number }>;
}

function reqEnv(k: string): string {
  const v = process.env[k];
  if (!v) throw new Error(`Missing env ${k} — run /infra to regenerate .env.test`);
  return v;
}

async function globalSetup() {
  fs.mkdirSync(AUTH_DIR, { recursive: true });
  const token = await fetchRopcToken();
  const baseURL = reqEnv('E2E_BASE_URL');
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto(baseURL);
  await page.evaluate((t) => {
    localStorage.setItem('e2e.access_token', t.access_token);
    localStorage.setItem('e2e.id_token', t.id_token);
  }, token);
  await page.context().storageState({ path: STATE });
  await browser.close();
  console.log('E2E auth ready — real Entra token injected, MFA UI bypassed.');
}

export default globalSetup;
```

### `docker-compose.test.yml` — materialize to project root

```yaml
# docker-compose.test.yml — E2E test stack (local-docker mode).
# TEMPLATE — adjust build contexts and ports for your project layout.
services:
  backend:
    build:
      context: ./backend          # <-- adjust
    environment:
      SQL_SERVER: ${E2E_SQL_SERVER}
      SQL_DB: ${E2E_SQL_DB}
      SQL_USER: ${E2E_SQL_USER}
      SQL_PASSWORD: ${E2E_SQL_PASSWORD}
      TENANT_ID: ${E2E_TENANT_ID}
      CLIENT_ID: ${E2E_CLIENT_ID}
      STORAGE_CONN: ${E2E_STORAGE_CONN:-}
    ports:
      - "8081:8081"
    healthcheck:
      test: ["CMD", "curl", "-fs", "http://localhost:8081/health"]
      interval: 5s
      timeout: 3s
      retries: 12

  webapp:
    build:
      context: ./frontend         # <-- adjust
    environment:
      API_BASE_URL: http://backend:8081
      TENANT_ID: ${E2E_TENANT_ID}
      CLIENT_ID: ${E2E_CLIENT_ID}
    ports:
      - "8080:80"
    depends_on:
      backend:
        condition: service_healthy
```

### `scripts/e2e-stack.sh` — materialize to `scripts/`

```bash
#!/usr/bin/env bash
# scripts/e2e-stack.sh — E2E test stack lifecycle.
set -euo pipefail
cd "$(dirname "$0")/.."

CMD="${1:-}"
COMPOSE="docker-compose.test.yml"
ENVFILE=".env.test"

[ -f "$ENVFILE" ] || { echo "missing $ENVFILE — run /infra to generate it"; exit 1; }
set -a; . "./$ENVFILE"; set +a

if [ "${E2E_STACK_EXTERNAL:-}" = "1" ]; then
  echo "[e2e-stack] E2E_STACK_EXTERNAL=1 — targeting deployed Azure app at ${E2E_BASE_URL:-<unset>}"
  case "$CMD" in
    up)
      echo "[e2e-stack] Verifying Azure app is reachable..."
      for i in $(seq 1 10); do
        if curl -fs "${E2E_BASE_URL:-http://localhost:8080}/health" >/dev/null 2>&1 \
        || curl -fs "${E2E_BASE_URL:-http://localhost:8080}" >/dev/null 2>&1; then
          echo "[e2e-stack] Azure app reachable."
          exit 0
        fi
        sleep 3
      done
      echo "[e2e-stack] WARNING: Azure app not reachable. Classify as AZURE UNAVAILABLE."
      exit 1
      ;;
    down)
      echo "[e2e-stack] External mode — nothing to stop."
      exit 0
      ;;
    *)
      echo "usage: e2e-stack.sh up|down"
      exit 1
      ;;
  esac
fi

if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

case "$CMD" in
  up)
    echo "[e2e-stack] building + starting local app containers..."
    $DC -f "$COMPOSE" --env-file "$ENVFILE" up -d --build
    for i in $(seq 1 30); do
      if curl -fs "${E2E_BASE_URL:-http://localhost:8080}" >/dev/null 2>&1; then
        echo "[e2e-stack] up."
        exit 0
      fi
      sleep 3
    done
    echo "[e2e-stack] ERROR: app did not become healthy — STACK NOT READY"
    exit 1
    ;;
  down)
    echo "[e2e-stack] stopping local containers..."
    $DC -f "$COMPOSE" --env-file "$ENVFILE" down
    echo "[e2e-stack] down."
    ;;
  *)
    echo "usage: e2e-stack.sh up|down"
    exit 1
    ;;
esac
```
