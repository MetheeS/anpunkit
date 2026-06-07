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

// Pass through recognised flags only; setup.sh validates the rest.
const passthrough = ['--kb-path', '--kb-remote', '--no-kb', '--force', '--dry-run'];
const argv = process.argv.slice(2);
const args = ['--src', TEMPLATE];
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (passthrough.includes(a)) {
    args.push(a);
    if (a === '--kb-path' || a === '--kb-remote') { args.push(argv[++i]); }
  } else {
    console.error(`create-anpunkit: unknown flag '${a}'. Allowed: ${passthrough.join(' ')}`);
    process.exit(2);
  }
}

const bash = process.platform === 'win32' ? 'bash' : 'bash'; // Git Bash / WSL on Windows
console.log(`create-anpunkit -> running setup.sh (src: ${TEMPLATE})`);
const r = spawnSync(bash, [SETUP, ...args], { stdio: 'inherit', cwd: process.cwd() });
if (r.error) {
  console.error('create-anpunkit: could not run bash. Install Git Bash (Windows) or ensure bash is on PATH.');
  process.exit(1);
}
process.exit(r.status === null ? 1 : r.status);
