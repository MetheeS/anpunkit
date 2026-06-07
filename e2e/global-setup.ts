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
