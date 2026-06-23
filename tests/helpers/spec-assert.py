"""spec-assert.py — kit-versioned matcher-aware deep-equality comparator (v2.2).

The generated `data` boundary harness (test-author) asserts an actual response
against `fixtures/<case-id>-expected.json` via `spec_assert(actual, expected)`.
Deep equality, EXCEPT that volatile fields in the expected fixture carry a matcher
token instead of a literal (see §5.49). This is the ONLY comparator — no per-project
assertion logic. One file per supported test language; this is the Python one.

Matcher tokens (string values in the expected fixture):

    "<UUID>"            any UUID v4 string
    "<ISO8601>"         any ISO 8601 datetime string
    "<ANY_STRING>"      any non-null string
    "<ANY_NUMBER>"      any finite number (not bool)
    "<UNORDERED>"       any array (presence + shape only)
    "<MATCHES:regex>"   any string matching the pattern (re.search)

Order-insensitive array WITH item checking: wrap the expected array as
    {"<UNORDERED>": [item, item, ...]}
and the actual must be a list that is an order-insensitive deep-equal multiset of
those items.

A matcher token asserts PRESENCE + SHAPE — never "ignore this field". A missing
volatile field still fails (strict key sets). Extra actual keys also fail.

Usage (pytest or any runner):

    from importlib import import_module
    spec_assert = import_module("tests.helpers.spec-assert").spec_assert  # if importable
    # or load directly:
    #   import importlib.util, pathlib
    #   spec = importlib.util.spec_from_file_location("spec_assert", ".../spec-assert.py")
    ...
    spec_assert(actual, expected)          # raises AssertionError with a JSON path on mismatch
"""

from __future__ import annotations

import json
import re
from numbers import Number
from pathlib import Path
from typing import Any

_UUID4 = re.compile(
    r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$"
)
_ISO8601 = re.compile(
    r"^\d{4}-\d{2}-\d{2}[Tt ]\d{2}:\d{2}:\d{2}(\.\d+)?([Zz]|[+-]\d{2}:?\d{2})?$"
)
_MATCHES_PREFIX = "<MATCHES:"


class SpecMismatch(AssertionError):
    """Raised when actual does not satisfy the expected fixture (with a JSON path)."""


def load_fixture(path: str | Path) -> Any:
    """Convenience loader for fixtures/<case-id>-*.json."""
    return json.loads(Path(path).read_text(encoding="utf-8"))


def _is_real_number(v: Any) -> bool:
    # bool is a subclass of int in Python — exclude it explicitly.
    return isinstance(v, Number) and not isinstance(v, bool)


def _fail(path: str, msg: str) -> None:
    raise SpecMismatch(f"spec-assert mismatch at {path}: {msg}")


def _match_token(actual: Any, token: str, path: str) -> bool:
    """Return True if `token` is a known matcher and `actual` satisfies it.
    Raises on a known token that is NOT satisfied. Returns False if not a token."""
    if token == "<UUID>":
        if not (isinstance(actual, str) and _UUID4.match(actual)):
            _fail(path, f"expected a UUID v4 string, got {actual!r}")
        return True
    if token == "<ISO8601>":
        if not (isinstance(actual, str) and _ISO8601.match(actual)):
            _fail(path, f"expected an ISO 8601 datetime string, got {actual!r}")
        return True
    if token == "<ANY_STRING>":
        if not isinstance(actual, str):
            _fail(path, f"expected any string, got {type(actual).__name__}")
        return True
    if token == "<ANY_NUMBER>":
        if not _is_real_number(actual):
            _fail(path, f"expected any finite number, got {actual!r}")
        return True
    if token == "<UNORDERED>":
        if not isinstance(actual, list):
            _fail(path, f"expected any array, got {type(actual).__name__}")
        return True
    if token.startswith(_MATCHES_PREFIX) and token.endswith(">"):
        pattern = token[len(_MATCHES_PREFIX):-1]
        if not (isinstance(actual, str) and re.search(pattern, actual)):
            _fail(path, f"expected a string matching /{pattern}/, got {actual!r}")
        return True
    return False


def _unordered_equal(actual: list, items: list, path: str) -> None:
    if not isinstance(actual, list):
        _fail(path, f"expected an array (unordered), got {type(actual).__name__}")
    if len(actual) != len(items):
        _fail(path, f"array length {len(actual)} != expected {len(items)} (unordered)")
    remaining = list(actual)
    for i, exp in enumerate(items):
        found = -1
        for j, act in enumerate(remaining):
            try:
                spec_assert(act, exp, f"{path}[unordered:{i}]")
                found = j
                break
            except SpecMismatch:
                continue
        if found < 0:
            _fail(path, f"no actual element matches expected item #{i}: {exp!r}")
        remaining.pop(found)


def spec_assert(actual: Any, expected: Any, path: str = "$") -> None:
    """Assert `actual` deep-equals `expected`, honoring matcher tokens. Raises
    SpecMismatch (an AssertionError) with a JSON path on the first divergence."""
    # scalar matcher token
    if isinstance(expected, str) and _match_token(actual, expected, path):
        return

    # {"<UNORDERED>": [...]} wrapper → order-insensitive item compare
    if isinstance(expected, dict) and list(expected.keys()) == ["<UNORDERED>"]:
        _unordered_equal(actual, expected["<UNORDERED>"], path)
        return

    if isinstance(expected, dict):
        if not isinstance(actual, dict):
            _fail(path, f"expected object, got {type(actual).__name__}")
        exp_keys, act_keys = set(expected), set(actual)
        if exp_keys != act_keys:
            missing = exp_keys - act_keys
            extra = act_keys - exp_keys
            _fail(path, f"key mismatch (missing={sorted(missing)}, extra={sorted(extra)})")
        for k in expected:
            spec_assert(actual[k], expected[k], f"{path}.{k}")
        return

    if isinstance(expected, list):
        if not isinstance(actual, list):
            _fail(path, f"expected array, got {type(actual).__name__}")
        if len(actual) != len(expected):
            _fail(path, f"array length {len(actual)} != expected {len(expected)}")
        for i, (a, e) in enumerate(zip(actual, expected)):
            spec_assert(a, e, f"{path}[{i}]")
        return

    # scalar literal — strict equality (bool/int kept distinct)
    if type(actual) is not type(expected) and not (
        _is_real_number(actual) and _is_real_number(expected)
    ):
        _fail(path, f"type {type(actual).__name__} != expected {type(expected).__name__}")
    if actual != expected:
        _fail(path, f"{actual!r} != expected {expected!r}")
