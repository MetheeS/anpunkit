# create-anpunkit

`npx`-installable scaffolder for the [anpunkit](../README.md) AI-coding workflow.

```bash
npx create-anpunkit                     # install into the current directory
npx create-anpunkit --dry-run           # show the plan, write nothing
npx create-anpunkit --kb-path ~/anpunkit-kb
npx create-anpunkit --no-kb
npx create-anpunkit --force             # overwrite user-modified kit files
```

## How it works

The bin is intentionally thin. It does NOT reimplement install logic: it locates
the embedded kit in `template/` and runs `bash template/setup.sh --src template`
in your current directory. `setup.sh` is the single source of truth for the
ownership taxonomy, adapter generation, hook merging, VERIFY, and KB config.

Assumes Node >= 18 and `bash` on PATH (Git Bash on Windows). Claude Code already
requires Node, so this adds no new dependency for its users.

## Publishing (maintainers)

GitHub is the source of truth; npm is a build artifact. Releases are tag-driven:

```bash
# bump version in BOTH package.json and .claude/anpunkit-manifest.json, commit, then:
git tag v2.0.1 && git push --tags
# .github/workflows/publish.yml verifies version sync, builds template/,
# smoke-tests a fresh install, and publishes to npm with --provenance.
```

Requires the `NPM_TOKEN` repo secret (npm granular access token, publish rights).

Manual fallback:

```bash
bash build.sh        # copies the kit tree into template/
npm publish --access public
```

`template/` is build output and is gitignored; `build.sh` regenerates it from the
repo root before each publish.
