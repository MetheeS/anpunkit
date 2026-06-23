/**
 * spec-assert.ts — kit-versioned matcher-aware deep-equality comparator (v2.2).
 *
 * The generated `data`/`ui` boundary harness asserts an actual value against
 * `fixtures/<case-id>-expected.json` via `specAssert(actual, expected)`. Deep
 * equality, EXCEPT that volatile fields in the expected fixture carry a matcher
 * token instead of a literal (§5.49). This is the ONLY comparator — no per-project
 * assertion logic. One file per supported test language; this is the TS/JS one.
 *
 * Matcher tokens (string values in the expected fixture):
 *
 *   "<UUID>"            any UUID v4 string
 *   "<ISO8601>"         any ISO 8601 datetime string
 *   "<ANY_STRING>"      any string
 *   "<ANY_NUMBER>"      any finite number
 *   "<UNORDERED>"       any array (presence + shape only)
 *   "<MATCHES:regex>"   any string matching the pattern (RegExp.test)
 *
 * Order-insensitive array WITH item checking: wrap the expected array as
 *   { "<UNORDERED>": [item, item, ...] }
 * and the actual must be an array that is an order-insensitive deep-equal multiset.
 *
 * A token asserts PRESENCE + SHAPE — never "ignore this field". Missing volatile
 * fields fail (strict key sets); extra actual keys also fail.
 *
 *   import { specAssert, loadFixture } from "../helpers/spec-assert";
 *   specAssert(actual, loadFixture("fixtures/PH2-ORDER-01-expected.json"));
 */

import { readFileSync } from "node:fs";

const UUID4 =
  /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$/;
const ISO8601 =
  /^\d{4}-\d{2}-\d{2}[Tt ]\d{2}:\d{2}:\d{2}(\.\d+)?([Zz]|[+-]\d{2}:?\d{2})?$/;
const MATCHES_PREFIX = "<MATCHES:";

export class SpecMismatch extends Error {
  constructor(message: string) {
    super(message);
    this.name = "SpecMismatch";
  }
}

export function loadFixture<T = unknown>(path: string): T {
  return JSON.parse(readFileSync(path, "utf-8")) as T;
}

function fail(path: string, msg: string): never {
  throw new SpecMismatch(`spec-assert mismatch at ${path}: ${msg}`);
}

function isPlainObject(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function typeName(v: unknown): string {
  if (v === null) return "null";
  if (Array.isArray(v)) return "array";
  return typeof v;
}

/** Returns true if `token` is a known matcher and `actual` satisfies it.
 *  Throws on a known token that is NOT satisfied. Returns false if not a token. */
function matchToken(actual: unknown, token: string, path: string): boolean {
  switch (token) {
    case "<UUID>":
      if (!(typeof actual === "string" && UUID4.test(actual)))
        fail(path, `expected a UUID v4 string, got ${JSON.stringify(actual)}`);
      return true;
    case "<ISO8601>":
      if (!(typeof actual === "string" && ISO8601.test(actual)))
        fail(path, `expected an ISO 8601 datetime string, got ${JSON.stringify(actual)}`);
      return true;
    case "<ANY_STRING>":
      if (typeof actual !== "string")
        fail(path, `expected any string, got ${typeName(actual)}`);
      return true;
    case "<ANY_NUMBER>":
      if (typeof actual !== "number" || !Number.isFinite(actual))
        fail(path, `expected any finite number, got ${JSON.stringify(actual)}`);
      return true;
    case "<UNORDERED>":
      if (!Array.isArray(actual))
        fail(path, `expected any array, got ${typeName(actual)}`);
      return true;
  }
  if (token.startsWith(MATCHES_PREFIX) && token.endsWith(">")) {
    const pattern = token.slice(MATCHES_PREFIX.length, -1);
    if (!(typeof actual === "string" && new RegExp(pattern).test(actual)))
      fail(path, `expected a string matching /${pattern}/, got ${JSON.stringify(actual)}`);
    return true;
  }
  return false;
}

function unorderedEqual(actual: unknown, items: unknown[], path: string): void {
  if (!Array.isArray(actual))
    fail(path, `expected an array (unordered), got ${typeName(actual)}`);
  if (actual.length !== items.length)
    fail(path, `array length ${actual.length} != expected ${items.length} (unordered)`);
  const remaining = [...actual];
  items.forEach((exp, i) => {
    let found = -1;
    for (let j = 0; j < remaining.length; j++) {
      try {
        specAssert(remaining[j], exp, `${path}[unordered:${i}]`);
        found = j;
        break;
      } catch (e) {
        if (e instanceof SpecMismatch) continue;
        throw e;
      }
    }
    if (found < 0) fail(path, `no actual element matches expected item #${i}: ${JSON.stringify(exp)}`);
    remaining.splice(found, 1);
  });
}

/** Assert `actual` deep-equals `expected`, honoring matcher tokens. Throws
 *  SpecMismatch with a JSON path on the first divergence. */
export function specAssert(actual: unknown, expected: unknown, path = "$"): void {
  // scalar matcher token
  if (typeof expected === "string" && matchToken(actual, expected, path)) return;

  // { "<UNORDERED>": [...] } wrapper → order-insensitive item compare
  if (isPlainObject(expected)) {
    const keys = Object.keys(expected);
    if (keys.length === 1 && keys[0] === "<UNORDERED>") {
      unorderedEqual(actual, expected["<UNORDERED>"] as unknown[], path);
      return;
    }
    if (!isPlainObject(actual)) fail(path, `expected object, got ${typeName(actual)}`);
    const expKeys = new Set(keys);
    const actKeys = new Set(Object.keys(actual));
    const missing = [...expKeys].filter((k) => !actKeys.has(k));
    const extra = [...actKeys].filter((k) => !expKeys.has(k));
    if (missing.length || extra.length)
      fail(path, `key mismatch (missing=${JSON.stringify(missing)}, extra=${JSON.stringify(extra)})`);
    for (const k of keys) specAssert(actual[k], expected[k], `${path}.${k}`);
    return;
  }

  if (Array.isArray(expected)) {
    if (!Array.isArray(actual)) fail(path, `expected array, got ${typeName(actual)}`);
    if (actual.length !== expected.length)
      fail(path, `array length ${actual.length} != expected ${expected.length}`);
    for (let i = 0; i < expected.length; i++)
      specAssert(actual[i], expected[i], `${path}[${i}]`);
    return;
  }

  // scalar literal — strict equality (typeof must agree; NaN-safe)
  if (typeName(actual) !== typeName(expected))
    fail(path, `type ${typeName(actual)} != expected ${typeName(expected)}`);
  if (actual !== expected && !(Number.isNaN(actual) && Number.isNaN(expected)))
    fail(path, `${JSON.stringify(actual)} != expected ${JSON.stringify(expected)}`);
}
