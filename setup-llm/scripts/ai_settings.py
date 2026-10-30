"""Fixture-only AI preference preservation. No profile discovery or external services."""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import uuid

if not (3, 11) <= sys.version_info[:2] < (3, 15):
    print('{"changed":false,"attention":[],"items":[],"error":"python-3.11-through-3.14-required"}')
    sys.exit(1)
import tomllib


class SettingsError(Exception):
    """Only fixed codes and reviewed identifiers may cross the reporting boundary."""


MISSING = object()
TARGETS = {"claude": "settings.json", "codex": "config.toml"}
DEFERRED = ["claude-desktop", "chatgpt", "authored-text", "skills", "other-profile-files", "secrets"]


def fail(code):
    raise SettingsError(code)


def json_load(raw):
    def pairs(entries):
        result = {}
        for key, value in entries:
            if key in result:
                fail("duplicate-json-key")
            result[key] = value
        return result

    def finite(text):
        # Overflowing literals such as 1e400 become inf without reaching parse_constant.
        value = float(text)
        if not math.isfinite(value):
            fail("invalid-json-number")
        return value

    try:
        return json.loads(raw, object_pairs_hook=pairs, parse_float=finite,
                          parse_constant=lambda _: fail("invalid-json-number"))
    except (ValueError, UnicodeError):
        fail("malformed-json")


def encode(data):
    return (json.dumps(data, indent=2, ensure_ascii=False, allow_nan=False) + "\n").encode("utf-8")


def prefix(a, b):
    return b[:len(a)] == a


def validate_manifest(manifest):
    if not isinstance(manifest, dict) or set(manifest) != {"version", "targets"}:
        fail("invalid-manifest")
    if type(manifest["version"]) is not int or manifest["version"] < 1:
        fail("invalid-manifest-version")
    if not isinstance(manifest["targets"], dict) or set(manifest["targets"]) != set(TARGETS):
        fail("invalid-manifest-targets")
    counts = {"owned": 0, "ignored": 0, "inspectionSpaces": 0}
    for target, spec in manifest["targets"].items():
        if not isinstance(spec, dict) or set(spec) != {"inspect", "ignored", "owned"}:
            fail("invalid-manifest-target")
        if spec["inspect"] != [[]]:
            fail("unsupported-inspection-space")
        counts["inspectionSpaces"] += 1
        if not isinstance(spec["owned"], list) or not spec["owned"] or not isinstance(spec["ignored"], list):
            fail("invalid-manifest-paths")
        all_paths = []
        for owned, entries in ((False, spec["ignored"]), (True, spec["owned"])):
            for entry in entries:
                if not isinstance(entry, dict):
                    fail("invalid-manifest-entry")
                required = {"path", "type", "securityRelevant", "sensitivity"} if owned else {"path", "reason"}
                optional = {"min", "max", "values", "pattern", "maxLength"} if owned else set()
                if not required <= set(entry) or set(entry) - required - optional:
                    fail("invalid-manifest-entry")
                path = entry["path"]
                if not isinstance(path, list) or not path or any(not isinstance(p, str) or not p for p in path):
                    fail("invalid-manifest-path")
                if any(prefix(p, path) or prefix(path, p) for p in all_paths):
                    fail("overlapping-manifest-path")
                all_paths.append(path)
                if not owned:
                    if not isinstance(entry["reason"], str) or not entry["reason"]:
                        fail("invalid-ignore-reason")
                    counts["ignored"] += 1
                    continue
                if target == "codex" and len(path) != 1:
                    fail("owned-toml-must-be-top-level")
                if entry["type"] not in ("string", "integer", "boolean"):
                    fail("owned-must-be-scalar")
                if type(entry["securityRelevant"]) is not bool or entry["sensitivity"] != "reviewed-preference":
                    fail("invalid-manifest-metadata")
                if entry["type"] == "integer":
                    if set(entry) & {"pattern", "maxLength"} or not {"min", "max"} <= set(entry):
                        fail("invalid-integer-rule")
                    if type(entry["min"]) is not int or type(entry["max"]) is not int or entry["min"] > entry["max"]:
                        fail("invalid-integer-rule")
                elif set(entry) & {"min", "max"}:
                    fail("invalid-scalar-rule")
                if entry["type"] == "boolean" and set(entry) & {"values", "pattern", "maxLength"}:
                    fail("invalid-boolean-rule")
                if entry["type"] == "string":
                    if type(entry.get("maxLength")) is not int or not 1 <= entry["maxLength"] <= 1024:
                        fail("invalid-string-rule")
                    if ("values" in entry) == ("pattern" in entry):
                        fail("invalid-string-rule")
                    if "pattern" in entry:
                        try:
                            re.compile(entry["pattern"])
                        except (TypeError, re.error):
                            fail("invalid-pattern")
                if "values" in entry:
                    values = entry["values"]
                    if not isinstance(values, list) or not values or len({repr(v) for v in values}) != len(values):
                        fail("invalid-values-rule")
                    for value in values:
                        validate_value(value, {k: v for k, v in entry.items() if k != "values"})
                counts["owned"] += 1
    return counts


def validate_value(value, rule):
    expected = {"string": str, "integer": int, "boolean": bool}[rule["type"]]
    if type(value) is not expected:
        fail("invalid-owned-type")
    if expected is int and not rule["min"] <= value <= rule["max"]:
        fail("invalid-owned-range")
    if expected is str:
        if not value or len(value) > rule["maxLength"]:
            fail("invalid-owned-string")
        if "pattern" in rule and not re.fullmatch(rule["pattern"], value):
            fail("invalid-owned-string")
    if "values" in rule and value not in rule["values"]:
        fail("invalid-owned-enum")


def get(data, path):
    for part in path:
        if not isinstance(data, dict):
            fail("invalid-owned-parent")
        if part not in data:
            return MISSING
        data = data[part]
    return data


def assign(data, path, action):
    parent = data
    for part in path[:-1]:
        if part not in parent:
            if action["action"] == "unset":
                return
            parent[part] = {}
        if not isinstance(parent[part], dict):
            fail("invalid-owned-parent")
        parent = parent[part]
    if action["action"] == "unset":
        parent.pop(path[-1], None)
    else:
        parent[path[-1]] = action["value"]


def semantic_equal(a, b):
    if type(a) is not type(b):
        return False
    if isinstance(a, dict):
        return a.keys() == b.keys() and all(semantic_equal(a[k], b[k]) for k in a)
    if isinstance(a, list):
        return len(a) == len(b) and all(semantic_equal(x, y) for x, y in zip(a, b))
    if isinstance(a, float) and math.isnan(a) and math.isnan(b):
        return True
    return a == b


def statements(text):
    """Locate TOML statements, including multiline strings/arrays/inline tables.

    Syntax authority is tomllib; this scanner only finds byte-preserving edit spans.
    """
    start = i = depth = 0
    quote = None
    while i < len(text):
        char = text[i]
        if quote:
            if quote[0] == '"' and char == "\\":
                i += 2
                continue
            if text.startswith(quote, i):
                i += len(quote)
                # TOML permits one or two quote characters before a triple close.
                if len(quote) == 3:
                    while i < len(text) and text[i] == quote[0]:
                        i += 1
                quote = None
                continue
        elif char in "\"'":
            quote = char * 3 if text.startswith(char * 3, i) else char
            i += len(quote)
            continue
        elif char == "#":
            end = text.find("\n", i)
            i = len(text) if end == -1 else end
            continue
        elif char in "[{":
            depth += 1
        elif char in "]}":
            depth -= 1
        elif char == "\n" and depth == 0:
            yield start, i + 1, text[start:i + 1]
            start = i + 1
        i += 1
    if start < len(text):
        yield start, len(text), text[start:]


def outside_index(text, wanted):
    quote = None
    i = 0
    while i < len(text):
        char = text[i]
        if quote:
            if quote == '"' and char == "\\":
                i += 2
                continue
            if char == quote:
                quote = None
        elif char in "\"'":
            quote = char
        elif char == wanted:
            return i
        i += 1
    return -1


def toml_spans(text, rules):
    names = {r["path"][0] for r in rules}
    spans = {}
    prelude_end = len(text)
    # Comments and blank lines directly above a header belong to that table.
    last_statement_end = 0
    for start, end, statement in statements(text):
        trimmed = statement.lstrip()
        if not trimmed or trimmed.startswith("#"):
            continue
        if trimmed.startswith("["):
            prelude_end = last_statement_end
            break
        last_statement_end = end
        equals = outside_index(statement, "=")
        if equals < 0:
            fail("unsupported-toml-statement")
        probe = tomllib.loads(statement[:equals] + "=0")
        key = next(iter(probe))
        if key not in names:
            continue
        if isinstance(probe[key], dict) or "\n" in statement.rstrip("\r\n") or "\r" in statement.rstrip("\r\n"):
            fail("unsupported-owned-toml-form")
        body_end = len(statement.rstrip("\r\n"))
        value_start = equals + 1
        while value_start < body_end and statement[value_start] in " \t":
            value_start += 1
        comment = outside_index(statement[value_start:body_end], "#")
        value_end = body_end if comment < 0 else value_start + comment
        while value_end > value_start and statement[value_end - 1] in " \t":
            value_end -= 1
        if statement[value_start:value_start + 3] in ('"""', "'''"):
            fail("unsupported-owned-toml-form")
        spans[key] = (start, end, start + value_start, start + value_end)
    return spans, prelude_end


def parse(raw, target, rules):
    try:
        text = raw.decode("utf-8")
    except UnicodeError:
        fail("unsupported-encoding")
    if text.startswith("\ufeff"):
        fail("unsupported-encoding")
    if target == "claude":
        data = json_load(text)
        if not isinstance(data, dict):
            fail("json-root-must-be-object")
    else:
        try:
            data = tomllib.loads(text)
            spans, _ = toml_spans(text, rules)
        except tomllib.TOMLDecodeError:
            fail("malformed-toml")
        for rule in rules:
            key = rule["path"][0]
            if key in data and key not in spans:
                fail("unsupported-owned-toml-form")
    for rule in rules:
        value = get(data, rule["path"])
        if value is not MISSING:
            validate_value(value, rule)
    return text, data


def action_for(data, path):
    value = get(data, path)
    return {"action": "unset"} if value is MISSING else {"action": "set", "value": value}


def plan(raw, target, rules, actions):
    text, data = parse(raw, target, rules)
    desired = copy.deepcopy(data)
    changed = []
    for rule, action in zip(rules, actions):
        if not semantic_equal(action_for(data, rule["path"]), action):
            changed.append(rule)
        assign(desired, rule["path"], action)
    if not changed:
        return raw, []
    if target == "claude":
        output = encode(desired)
    else:
        spans, end = toml_spans(text, rules)
        edits = []
        additions = []
        newline = "\r\n" if "\r\n" in text else "\n"
        for rule, action in zip(rules, actions):
            if rule not in changed:
                continue
            key = rule["path"][0]
            span = spans.get(key)
            if action["action"] == "unset":
                if span:
                    edits.append((span[0], span[1], ""))
            else:
                literal = json.dumps(action["value"], ensure_ascii=False)
                if span:
                    edits.append((span[2], span[3], literal))
                else:
                    additions.append(f"{json.dumps(key)} = {literal}{newline}")
        if additions:
            lead = newline if end and text[end - 1] != "\n" else ""
            edits.append((end, end, lead + "".join(additions)))
        for start, finish, replacement in sorted(edits, reverse=True):
            text = text[:start] + replacement + text[finish:]
        output = text.encode("utf-8")
    _, actual = parse(output, target, rules)
    if not semantic_equal(actual, desired):
        fail("semantic-verification-failed")
    return output, changed


def fingerprint(path):
    # A writer active during the read gets the same three attempts as a check conflict.
    for _ in range(3):
        try:
            before = path.stat()
            raw = path.read_bytes()
            after = path.stat()
        except FileNotFoundError:
            return None, None
        if (before.st_size, before.st_mtime_ns) == (after.st_size, after.st_mtime_ns):
            return (after.st_size, after.st_mtime_ns, hashlib.sha256(raw).digest()), raw
    fail("concurrent-modification")


def temp_absolute(path):
    """Normalize the OS temp prefix (macOS /var alias), never links below it."""
    path = Path(path).absolute()
    temp_alias = Path(tempfile.gettempdir()).absolute()
    if path.is_relative_to(temp_alias):
        return temp_alias.resolve() / path.relative_to(temp_alias)
    return path


def private_dir(path):
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    if os.name == "nt":
        # SID form works on localized Windows. Never print command diagnostics.
        identity = subprocess.run(["whoami", "/user", "/fo", "csv", "/nh"], capture_output=True, check=True)
        sid_match = re.search(rb"S-1-(?:[0-9]+-)*[0-9]+", identity.stdout)
        if not sid_match:
            fail("backup-permissions-failed")
        sid = sid_match[0].decode("ascii")
        # Replace the DACL, including explicit stale grants, in one native call.
        import ctypes
        from ctypes import wintypes
        security = ctypes.WinDLL("advapi32", use_last_error=True)
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        security.ConvertStringSecurityDescriptorToSecurityDescriptorW.argtypes = [
            wintypes.LPCWSTR, wintypes.DWORD, ctypes.POINTER(ctypes.c_void_p), ctypes.c_void_p]
        security.ConvertStringSecurityDescriptorToSecurityDescriptorW.restype = wintypes.BOOL
        security.SetFileSecurityW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, ctypes.c_void_p]
        security.SetFileSecurityW.restype = wintypes.BOOL
        kernel.LocalFree.argtypes = [ctypes.c_void_p]
        kernel.LocalFree.restype = ctypes.c_void_p
        descriptor = ctypes.c_void_p()
        if not security.ConvertStringSecurityDescriptorToSecurityDescriptorW(
                f"D:P(A;OICI;FA;;;{sid})", 1, ctypes.byref(descriptor), None):
            fail("backup-permissions-failed")
        try:
            if not security.SetFileSecurityW(str(path), 0x80000004, descriptor):
                fail("backup-permissions-failed")
        finally:
            kernel.LocalFree(descriptor)
    else:
        path.chmod(0o700)


def replace(path, raw):
    """Same-directory temporary file; replacement preserves mode, not a CAS lock."""
    descriptor, name = tempfile.mkstemp(prefix=".ai-settings-", dir=path.parent)
    temporary = Path(name)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(raw)
            stream.flush()
            os.fsync(stream.fileno())
        if path.exists():
            shutil.copymode(path, temporary)
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


class Manager:
    def __init__(self, sandbox, manifest, claude_home=None, codex_home=None,
                 data_path=None, backup_root=None, codex_running=lambda: False, hook=lambda *_: None):
        self.counts = validate_manifest(manifest)
        self.manifest = manifest
        requested = temp_absolute(sandbox)
        temp = Path(tempfile.gettempdir()).resolve()
        self.root = requested.resolve()
        if self.root == temp or not self.root.is_relative_to(temp) or self.root != requested or not self.root.is_dir():
            fail("sandbox-must-be-existing-temp-child")
        self.targets = {"claude": self.bound(claude_home or self.root / "claude") / TARGETS["claude"],
                        "codex": self.bound(codex_home or self.root / "codex") / TARGETS["codex"]}
        self.data = self.bound(data_path or self.root / "repo" / "preferences.json")
        self.backups = self.bound(backup_root or self.root / "private-backups")
        paths = [*(path.parent for path in self.targets.values()), self.data, self.backups]
        if any(a == b or a in b.parents or b in a.parents for i, a in enumerate(paths) for b in paths[i + 1:]):
            fail("overlapping-sandbox-paths")
        if self.backups.is_relative_to(self.data.parent):
            fail("backups-must-be-outside-data-repository")
        self.codex_running = codex_running
        self.hook = hook
        self.result = {"changed": False, "items": [], "attention": [],
                       "manifestCounts": self.counts, "coverage": {"inspected": list(TARGETS), "notInspected": DEFERRED}}

    def bound(self, path):
        path = temp_absolute(path)
        resolved = path.resolve()
        if resolved != path or resolved == self.root or not resolved.is_relative_to(self.root):
            fail("path-outside-sandbox-or-linked")
        # Reject every existing reparse point, including junctions.
        for part in [path, *path.parents]:
            if part == self.root.parent:
                break
            if part.exists() and getattr(part.lstat(), "st_file_attributes", 0) & 0x400:
                fail("path-outside-sandbox-or-linked")
        return resolved

    def read_target(self, target):
        path = self.bound(self.targets[target])
        observed, raw = fingerprint(path)
        if raw is None:
            fail("missing-target")
        text, data = parse(raw, target, self.manifest["targets"][target]["owned"])
        return observed, raw, text, data

    def snapshot(self):
        observed, raw = fingerprint(self.bound(self.data))
        if raw is None:
            fail("missing-snapshot")
        data = json_load(raw)
        if (not isinstance(data, dict) or set(data) != {"manifestVersion", "targets"}
                or type(data["manifestVersion"]) is not int or data["manifestVersion"] != self.manifest["version"]):
            fail("snapshot-version-or-shape")
        if not isinstance(data["targets"], dict) or set(data["targets"]) != set(TARGETS):
            fail("incomplete-snapshot")
        for target, spec in self.manifest["targets"].items():
            entries = data["targets"][target]
            if not isinstance(entries, list) or len(entries) != len(spec["owned"]):
                fail("incomplete-snapshot")
            for rule, entry in zip(spec["owned"], entries):
                if not isinstance(entry, dict) or entry.get("path") != rule["path"]:
                    fail("incomplete-snapshot")
                if entry.get("action") == "set" and set(entry) == {"path", "action", "value"}:
                    validate_value(entry["value"], rule)
                elif entry.get("action") != "unset" or set(entry) != {"path", "action"}:
                    fail("invalid-snapshot-action")
        return observed, data

    def classify(self, target, data, snapshot=None):
        spec = self.manifest["targets"][target]
        owned = {tuple(rule["path"]): rule for rule in spec["owned"]}
        ignored = {tuple(entry["path"]) for entry in spec["ignored"]}
        ordinal = 0

        def walk(value, path=()):
            nonlocal ordinal
            if path in ignored:
                self.result["items"].append({"target": target, "path": list(path), "outcome": "ignored"})
            elif path in owned:
                return
            elif isinstance(value, dict) and value:
                for key, child in value.items():
                    walk(child, (*path, key))
            elif isinstance(value, dict) and any(prefix(list(path), list(p)) for p in owned):
                return  # Empty structural parent of reviewed owned leaves.
            elif path:
                ordinal += 1
                suspect = any(re.search(r"token|secret|password|credential|api.?key|auth", key, re.I) for key in path)
                # Unknown names can themselves contain credentials. Emit an ordinal, never those names.
                self.result["attention"].append({"target": target, "item": ordinal,
                                                 "outcome": "suspected-secret" if suspect else "unclassified"})
        walk(data)
        for index, rule in enumerate(spec["owned"]):
            outcome = "owned" if snapshot is None else (
                "in-sync" if semantic_equal(action_for(data, rule["path"]),
                                            {k: v for k, v in snapshot[index].items() if k != "path"}) else "drift")
            self.result["items"].append({"target": target, "path": rule["path"], "outcome": outcome,
                                         "securityRelevant": rule["securityRelevant"]})

    def capture(self):
        captured = {"manifestVersion": self.manifest["version"], "targets": {}}
        sources = []
        for target, spec in self.manifest["targets"].items():
            observed, _, _, data = self.read_target(target)
            sources.append((target, observed))
            self.classify(target, data)
            captured["targets"][target] = [{"path": rule["path"], **action_for(data, rule["path"])} for rule in spec["owned"]]
        output = encode(captured)
        for attempt in range(3):
            observed, previous = fingerprint(self.bound(self.data))
            if previous == output:
                return self.result
            for target, source_fingerprint in sources:
                if fingerprint(self.bound(self.targets[target]))[0] != source_fingerprint:
                    fail("concurrent-modification")
            self.hook("capture-before-check", attempt, self.data)
            if fingerprint(self.bound(self.data))[0] != observed:
                continue
            self.data.parent.mkdir(parents=True, exist_ok=True)
            replace(self.data, output)
            self.result["changed"] = True
            if fingerprint(self.data)[1] != output:
                fail("overwritten-after-write")
            return self.result
        fail("concurrent-modification")

    def status(self):
        snapshot = None
        try:
            _, snapshot = self.snapshot()
        except (SettingsError, OSError):
            self.result["attention"].append({"outcome": "snapshot-unavailable"})
        for target in TARGETS:
            try:
                _, _, _, data = self.read_target(target)
                self.classify(target, data, snapshot["targets"][target] if snapshot else None)
            except SettingsError as error:
                self.result["attention"].append({"target": target, "outcome": "unavailable", "reason": str(error)})
            except OSError:
                self.result["attention"].append({"target": target, "outcome": "unavailable", "reason": "io-error"})
        return self.result

    def restore(self, what_if=False, force=False):
        if self.codex_running() and not force:
            fail("codex-running")
        _, snapshot = self.snapshot()
        planned = []
        # Complete preflight before backups or target writes.
        for target, spec in self.manifest["targets"].items():
            _, raw, _, data = self.read_target(target)
            actions = [{k: v for k, v in entry.items() if k != "path"} for entry in snapshot["targets"][target]]
            output, changes = plan(raw, target, spec["owned"], actions)
            self.classify(target, data, snapshot["targets"][target])
            planned.append((target, actions, output != raw))
            for rule in changes:
                self.result["items"].append({"target": target, "path": rule["path"], "outcome": "would-change",
                                             "securityRelevant": rule["securityRelevant"]})
        if what_if:
            self.result["wouldChange"] = any(changed for _, _, changed in planned)
            return self.result
        applied = []
        run = None
        try:
            for target, actions, _ in planned:
                path = self.targets[target]
                for attempt in range(3):
                    self.bound(path)
                    observed, raw, _, _ = self.read_target(target)
                    output, changes = plan(raw, target, self.manifest["targets"][target]["owned"], actions)
                    if not changes:
                        self.result["items"].append({"target": target, "outcome": "unchanged"})
                        break
                    self.hook("before-check", attempt, path)
                    if fingerprint(self.bound(path))[0] != observed:
                        continue
                    if run is None:
                        self.bound(self.backups)
                        private_dir(self.backups)
                        run = self.backups / uuid.uuid4().hex
                        private_dir(run)
                    backup = run / TARGETS[target]
                    backup.write_bytes(raw)
                    if fingerprint(self.bound(path))[0] != observed:
                        continue
                    self.hook("after-check", attempt, path)
                    try:
                        replace(self.bound(path), output)
                    except PermissionError:
                        if attempt < 2:
                            continue
                        fail("replace-failed")
                    item = {"target": target, "outcome": "applied"}
                    applied_entry = [path, raw, None, item]
                    applied.append(applied_entry)
                    self.result["items"].append(item)
                    self.result["changed"] = True
                    written, current = fingerprint(path)
                    # A post-write mismatch must never grant rollback ownership of external bytes.
                    applied_entry[2] = written if current == output else None
                    self.hook("after-write", attempt, path)
                    if fingerprint(self.bound(path))[0] != written or current != output:
                        fail("overwritten-after-write")
                    break
                else:
                    fail("concurrent-modification")
            if run:
                (run / "complete.json").write_bytes(encode({"completed": True}))
                try:
                    self.prune()
                except (OSError, SettingsError):
                    self.result["attention"].append({"outcome": "backup-retention-failed"})
            return self.result
        except (SettingsError, OSError):
            for path, raw, written, item in reversed(applied):
                try:
                    self.hook("before-rollback", 0, path)
                    if written is None or fingerprint(self.bound(path))[0] != written:
                        item["outcome"] = "rollback-conflict"
                        continue
                    replace(path, raw)
                    if fingerprint(path)[1] != raw:
                        item["outcome"] = "rollback-conflict"
                    else:
                        item["outcome"] = "rolled-back"
                except (OSError, SettingsError):
                    item["outcome"] = "rollback-failed"
            # Failed runs are intentionally never pruned automatically.
            raise

    def prune(self):
        completed = sorted((p for p in self.backups.iterdir() if p.is_dir() and (p / "complete.json").is_file()),
                           key=lambda p: p.stat().st_mtime_ns, reverse=True)
        for path in completed[5:]:
            self.bound(path)
            # Only delete files this command owns, never recursively follow arbitrary paths.
            if set(p.name for p in path.iterdir()) <= {*TARGETS.values(), "complete.json"}:
                for child in path.iterdir():
                    self.bound(child).unlink()
                path.rmdir()


def main():
    result = {"changed": False, "items": [], "attention": []}
    manager = None
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("capture", "status", "restore"))
    parser.add_argument("--sandbox-root", required=True)
    parser.add_argument("--manifest", default=str(Path(__file__).with_name("ai-settings.manifest.json")))
    for name in ("claude-home", "codex-home", "data-path", "backup-root"):
        parser.add_argument("--" + name)
    parser.add_argument("--codex-running", action="store_true")
    parser.add_argument("--what-if", action="store_true")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--fail-on-attention", action="store_true")
    args = parser.parse_args()
    try:
        if args.what_if and args.command != "restore":
            fail("what-if-requires-restore")
        manager = Manager(args.sandbox_root, json_load(Path(args.manifest).read_bytes()),
                          args.claude_home, args.codex_home, args.data_path, args.backup_root,
                          codex_running=lambda: args.codex_running)
        if args.command == "restore":
            result = manager.restore(args.what_if, args.force)
        else:
            result = getattr(manager, args.command)()
        code = 2 if args.fail_on_attention and result["attention"] else 0
    except SettingsError as error:
        result = manager.result if manager else result
        result["error"] = str(error)
        code = 1
    except Exception:
        result = manager.result if manager else result
        result["error"] = "io-or-internal-error"
        code = 1
    print(json.dumps(result, ensure_ascii=True, allow_nan=False))
    return code


if __name__ == "__main__":
    sys.exit(main())
