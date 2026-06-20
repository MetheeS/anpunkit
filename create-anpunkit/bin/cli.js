#!/usr/bin/env node
// create-anpunkit — thin scaffolder. Does NOT reimplement install logic:
// it locates the embedded kit (template/) and delegates everything to
// `bash setup.sh --src <template>` running in the user's current directory.
'use strict';
const path = require('path');
const fs = require('fs');
const { spawnSync } = require('child_process');

const TEMPLATE = path.join(__dirname, '..', 'template');
const SETUP = path.join(TEMPLATE, 'setup.sh');

if (!fs.existsSync(SETUP)) {
  console.error('create-anpunkit: embedded kit not found (template/setup.sh missing).');
  console.error('If running from source, build it first:  bash create-anpunkit/build.sh');
  process.exit(1);
}

// --- locate a REAL bash on Windows (never the System32 WSL relay).
// In PowerShell, bare `bash` resolves to C:\Windows\System32\bash.exe, which
// relays into WSL and fails with "execvpe(/bin/bash) failed" when no distro
// is installed. We must find Git Bash explicitly.
function findBash() {
  if (process.platform !== 'win32') return 'bash';
  const candidates = [];
  if (process.env.ANPUNKIT_BASH) candidates.push(process.env.ANPUNKIT_BASH);
  // Derive from git on PATH: <Git>\cmd\git.exe or <Git>\mingw64\bin\git.exe -> <Git>\bin\bash.exe
  try {
    const r = spawnSync('where', ['git'], { encoding: 'utf8' });
    if (r.status === 0) {
      for (const line of r.stdout.split(/\r?\n/).map(s => s.trim()).filter(Boolean)) {
        const d1 = path.resolve(path.dirname(line), '..');
        const d2 = path.resolve(d1, '..');
        candidates.push(path.join(d1, 'bin', 'bash.exe'), path.join(d2, 'bin', 'bash.exe'));
      }
    }
  } catch (_) { /* where.exe missing — fall through */ }
  // Standard Git for Windows install locations
  for (const base of [
    process.env.ProgramFiles,
    process.env['ProgramFiles(x86)'],
    process.env.LocalAppData ? path.join(process.env.LocalAppData, 'Programs') : null
  ]) {
    if (base) candidates.push(path.join(base, 'Git', 'bin', 'bash.exe'));
  }
  for (const c of candidates) {
    if (c && !/system32/i.test(c) && fs.existsSync(c)) return c;
  }
  return null;
}

const bash = findBash();
if (!bash) {
  console.error('create-anpunkit: could not find Git Bash.');
  console.error('The Windows `bash` on PATH is the WSL relay (System32), which is not usable here.');
  console.error('Fix one of:');
  console.error('  1. Install Git for Windows (includes Git Bash): https://git-scm.com/download/win');
  console.error('  2. Run `npx create-anpunkit` from a Git Bash terminal instead of PowerShell.');
  console.error('  3. Set ANPUNKIT_BASH to the full path of a bash.exe.');
  process.exit(1);
}

// Pass through recognised flags only; setup.sh validates the rest.
const passthrough = ['--kb-path', '--kb-remote', '--no-kb', '--force', '--dry-run', '--tools', '--add-tool'];
const valueFlags = ['--kb-path', '--kb-remote', '--tools', '--add-tool'];
const argv = process.argv.slice(2);
// Git Bash is happiest with forward slashes; Windows APIs accept them too.
const fwd = p => p.split(path.sep).join('/');
const args = ['--src', fwd(TEMPLATE)];
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (passthrough.includes(a)) {
    args.push(a);
    if (valueFlags.includes(a)) { args.push(argv[++i]); }
  } else {
    console.error(`create-anpunkit: unknown flag '${a}'. Allowed: ${passthrough.join(' ')}`);
    process.exit(2);
  }
}

console.log(`create-anpunkit -> running setup.sh (bash: ${bash})`);
const r = spawnSync(bash, [fwd(SETUP), ...args], { stdio: 'inherit', cwd: process.cwd() });
if (r.error) {
  console.error(`create-anpunkit: failed to run ${bash}: ${r.error.message}`);
  process.exit(1);
}
process.exit(r.status === null ? 1 : r.status);
