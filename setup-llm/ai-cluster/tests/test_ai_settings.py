"""S1 acceptance tests. Every profile is generated under TemporaryDirectory."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "ai_settings.py"
spec = importlib.util.spec_from_file_location("ai_settings", SCRIPT)
ai = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ai)
MANIFEST = json.loads(SCRIPT.with_name("ai-settings.manifest.json").read_bytes())
CANARY = "CANARY PRIVATE VALUE DO NOT PUBLISH 9328"


class SettingsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="ai-settings-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.claude = self.root / "claude" / "settings.json"
        self.codex = self.root / "codex" / "config.toml"
        self.claude.parent.mkdir()
        self.codex.parent.mkdir()
        self.claude.write_bytes(ai.encode({"model": "opus", "env": {"MAX_MCP_OUTPUT_TOKENS": "30000"}}))
        self.codex.write_bytes(b'model = "fixture-model"\nmodel_verbosity = "low"\n')

    def manager(self, **kwargs):
        return ai.Manager(self.root, copy.deepcopy(MANIFEST), **kwargs)

    def cli(self, command, *args):
        run = subprocess.run([sys.executable, "-I", str(SCRIPT), command,
                              "--sandbox-root", str(self.root), *args], capture_output=True, text=True)
        return run, json.loads(run.stdout)

    def capture(self):
        return self.manager().capture()

    def mutate(self):
        self.claude.write_bytes(ai.encode({"model": "sonnet", "Keep": 1, "keep": 2, "env": {"PRIVATE_KEY": CANARY}}))
        self.codex.write_bytes(b'model = "changed"\nmodel_verbosity = "high"\n')

    def tree(self):
        return {p.relative_to(self.root).as_posix(): (p.read_bytes(), p.stat().st_mtime_ns)
                for p in self.root.rglob("*") if p.is_file()}

    def test_capture_changed_idempotent_and_only_data_written(self):
        before = self.tree()
        run, result = self.cli("capture")
        self.assertEqual(run.returncode, 0)
        self.assertTrue(result["changed"])
        after = self.tree()
        self.assertEqual(set(after) - set(before), {"repo/preferences.json"})
        self.assertTrue(all(after[p] == value for p, value in before.items()))
        run, result = self.cli("capture")
        self.assertEqual(run.returncode, 0)
        self.assertFalse(result["changed"])
        self.assertEqual(self.tree(), after)

    def test_classification_precedence_exact_unknown_counts_and_exit_codes(self):
        self.capture()
        self.claude.write_bytes(ai.encode({"a": 1, "b": 2, "c": {}, "env": {"MAX_MCP_OUTPUT_TOKENS": "30000"}}))
        run, result = self.cli("status")
        self.assertEqual(run.returncode, 0)
        self.assertEqual([i["outcome"] for i in result["attention"]], ["unclassified"] * 3)
        run, _ = self.cli("status", "--fail-on-attention")
        self.assertEqual(run.returncode, 2)
        self.claude.write_bytes(ai.encode({"hooks": {"credential": CANARY}, "env": {"API_TOKEN": CANARY}}))
        _, result = self.cli("status")
        self.assertEqual(len(result["attention"]), 1)
        self.assertEqual(result["attention"][0]["outcome"], "suspected-secret")
        self.assertNotIn(CANARY, json.dumps(result))
        self.assertNotIn("API_TOKEN", json.dumps(result))

    def test_whatif_zero_writes_and_security_markers(self):
        self.codex.write_bytes(b'model="fixture-model"\nsandbox_mode="read-only"\napproval_policy="on-request"\n')
        self.capture()
        self.codex.write_bytes(b'model="other"\nsandbox_mode="danger-full-access"\napproval_policy="never"\n')
        before = self.tree()
        result = self.manager().restore(what_if=True)
        self.assertFalse(result["changed"])
        self.assertTrue(result["wouldChange"])
        changes = [i for i in result["items"] if i["outcome"] == "would-change"]
        self.assertEqual(sum(i["securityRelevant"] for i in changes), 2)
        self.assertEqual(self.tree(), before)
        self.assertFalse(self.manager().backups.exists())

    def test_json_unowned_case_sensitive_values_and_second_restore_no_writes(self):
        self.capture()
        self.mutate()
        result = self.manager().restore()
        self.assertTrue(result["changed"])
        data = json.loads(self.claude.read_bytes())
        self.assertEqual(data["Keep"], 1)
        self.assertEqual(data["keep"], 2)
        self.assertEqual(data["env"]["PRIVATE_KEY"], CANARY)
        self.assertEqual(data["env"]["MAX_MCP_OUTPUT_TOKENS"], "30000")
        before = self.tree()
        self.assertFalse(self.manager().restore()["changed"])
        self.assertEqual(self.tree(), before)

    def test_toml_lexical_boundaries_and_crlf_bytes(self):
        self.capture()
        suffix = ('notes = """fake\r\n[not.a.table]\r\nmodel="fake"\r\n"""\r\n'
                  "literal = '''[also.fake]\r\nmodel = 1\r\n'''\r\n"
                  'array = ["#", "[fake]",\r\n "\\\"quoted\\\""] # comment\r\n'
                  'inline = { value = "[fake]" }\r\n'
                  '[profiles.test]\r\nmodel = "nested"\r\n')
        self.codex.write_bytes(('  "model"  = "changed"  # Keep comment\r\n' + suffix).encode())
        self.manager().restore()
        output = self.codex.read_bytes()
        self.assertIn(b'  "model"  = "fixture-model"  # Keep comment\r\n', output)
        # Insertion occurs at the end of the real prelude; unknown statements are byte-identical.
        for statement in suffix.split('[profiles.test]')[0].splitlines(keepends=True):
            self.assertIn(statement.encode(), output)
        self.assertTrue(output.endswith(b'[profiles.test]\r\nmodel = "nested"\r\n'))
        parsed = ai.tomllib.loads(output.decode())
        self.assertEqual(parsed["profiles"]["test"]["model"], "nested")
        self.assertEqual(parsed["model_verbosity"], "low")

    def test_toml_quoted_keys_escapes_comments_missing_root_and_nan(self):
        self.capture()
        self.codex.write_bytes(b'"mo\\u0064el" = "other" # retained\nx = nan\n[profiles.a]\nmodel="nested"\n')
        self.manager().restore()
        self.assertIn(b'"mo\\u0064el" = "fixture-model" # retained', self.codex.read_bytes())
        self.assertIn(b'x = nan\n', self.codex.read_bytes())

    def test_owned_toml_unsupported_forms_refused_without_writes(self):
        self.capture()
        variants = [b'model.name="bad"\n', b'model={name="bad"}\n', b'model="a"\nmodel="b"\n',
                    b'model="""one line"""\n', b'model="""multiple\nlines"""\n',
                    b'[model]\nname="bad"\n', b'model=["bad"]\n', b'\xef\xbb\xbfmodel="bad"\n']
        for raw in variants:
            with self.subTest(raw=raw):
                self.codex.write_bytes(raw)
                before = self.tree()
                with self.assertRaises(ai.SettingsError):
                    self.manager().restore()
                self.assertEqual(self.tree(), before)

    def test_three_conflicts_retry_and_rollback_earlier_file(self):
        self.capture()
        self.mutate()
        before = self.claude.read_bytes()
        attempts = []

        def hook(event, attempt, path):
            if event == "before-check" and path == self.codex:
                attempts.append(attempt)
                path.write_bytes(path.read_bytes() + b"# competing writer\n")

        manager = self.manager(hook=hook)
        with self.assertRaisesRegex(ai.SettingsError, "concurrent-modification"):
            manager.restore()
        self.assertEqual(attempts, [0, 1, 2])
        self.assertEqual(self.claude.read_bytes(), before)
        self.assertIn("rolled-back", [i["outcome"] for i in manager.result["items"]])

    def test_retry_rebases_and_preserves_external_unowned_value(self):
        self.capture()
        self.mutate()

        def hook(event, attempt, path):
            if event == "before-check" and attempt == 0 and path == self.codex:
                path.write_bytes(path.read_bytes() + b"new_external = 42\n")

        self.manager(hook=hook).restore()
        self.assertEqual(ai.tomllib.loads(self.codex.read_text())["new_external"], 42)

    def test_known_check_replace_race_is_demonstrated_not_claimed_solved(self):
        self.capture()
        self.mutate()

        def hook(event, attempt, path):
            if event == "after-check" and path == self.codex:
                path.write_bytes(path.read_bytes() + b"lost_in_known_race = true\n")

        self.assertTrue(self.manager(hook=hook).restore()["changed"])
        self.assertNotIn(b"lost_in_known_race", self.codex.read_bytes())

    def test_postwrite_conflict_preserves_external_bytes_and_backup(self):
        self.capture()
        self.mutate()

        def hook(event, attempt, path):
            if event == "after-write" and path == self.claude:
                path.write_bytes(ai.encode({"external": CANARY}))

        manager = self.manager(hook=hook)
        with self.assertRaisesRegex(ai.SettingsError, "overwritten-after-write"):
            manager.restore()
        self.assertEqual(json.loads(self.claude.read_bytes()), {"external": CANARY})
        self.assertIn("rollback-conflict", [i["outcome"] for i in manager.result["items"]])
        self.assertTrue(list(manager.backups.glob("*/settings.json")))
        self.assertFalse(list(manager.backups.glob("*/complete.json")))

    def test_external_edit_of_earlier_file_survives_second_file_failure(self):
        self.capture()
        self.mutate()

        def hook(event, attempt, path):
            if event == "before-check" and path == self.codex:
                self.claude.write_bytes(ai.encode({"external": CANARY}))
                raise PermissionError("fixture failure")

        manager = self.manager(hook=hook)
        with self.assertRaises(PermissionError):
            manager.restore()
        self.assertEqual(json.loads(self.claude.read_bytes()), {"external": CANARY})
        self.assertIn("rollback-conflict", [i["outcome"] for i in manager.result["items"]])
        self.assertFalse(list(manager.backups.glob("*/complete.json")))

    @unittest.skipUnless(os.name == "nt", "Windows sharing semantics")
    def test_actual_windows_lock_on_second_file_rolls_back_first(self):
        import ctypes
        from ctypes import wintypes
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                                      wintypes.LPVOID, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
        kernel.CreateFileW.restype = wintypes.HANDLE
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        self.capture()
        self.mutate()
        before = self.claude.read_bytes()
        handle = None

        def hook(event, attempt, path):
            nonlocal handle
            if event == "after-write" and path == self.claude:
                handle = kernel.CreateFileW(str(self.codex), 0x80000000, 0, None, 3, 0, None)
                self.assertNotEqual(handle, wintypes.HANDLE(-1).value)

        manager = self.manager(hook=hook)
        try:
            with self.assertRaises(OSError):
                manager.restore()
        finally:
            if handle is not None:
                kernel.CloseHandle(handle)
        self.assertEqual(self.claude.read_bytes(), before)
        self.assertIn("rolled-back", [i["outcome"] for i in manager.result["items"]])

    def test_capture_destination_conflicts_fail_after_three_checks(self):
        self.capture()
        self.claude.write_bytes(b'{"model":"sonnet"}')
        attempts = []

        def hook(event, attempt, path):
            if event == "capture-before-check":
                attempts.append(attempt)
                path.write_bytes(b'{"external":true}\n' + b' ' * attempt)

        with self.assertRaisesRegex(ai.SettingsError, "concurrent-modification"):
            self.manager(hook=hook).capture()
        self.assertEqual(attempts, [0, 1, 2])
        self.assertEqual(json.loads(self.manager().data.read_bytes()), {"external": True})

    def test_change_during_read_is_retried_then_refused_after_three_reads(self):
        original = Path.read_bytes
        reads = []

        def racing(limit):
            def read(path):
                raw = original(path)
                if path == self.codex:
                    reads.append(path)
                    if len(reads) <= limit:
                        stat = path.stat()
                        os.utime(path, ns=(stat.st_atime_ns, stat.st_mtime_ns + 1_000_000_000))
                return raw
            return read

        with patch.object(Path, "read_bytes", racing(2)):
            _, raw = ai.fingerprint(self.codex)
        self.assertEqual((len(reads), raw), (3, self.codex.read_bytes()))
        reads.clear()
        with patch.object(Path, "read_bytes", racing(99)), \
                self.assertRaisesRegex(ai.SettingsError, "concurrent-modification"):
            ai.fingerprint(self.codex)
        self.assertEqual(len(reads), 3)

    def test_non_finite_json_numbers_are_refused_as_invalid(self):
        self.capture()
        baseline = self.manager().data.read_bytes()
        for raw in (b'{"autoCompactWindow": 1e400}', b'{"x": -1e400}', b'{"x": NaN}', b'{"x": Infinity}'):
            with self.subTest(raw=raw):
                self.claude.write_bytes(raw)
                run, result = self.cli("capture")
                self.assertEqual(run.returncode, 1)
                self.assertEqual(result["error"], "invalid-json-number")
                self.assertEqual(self.manager().data.read_bytes(), baseline)

    def test_toml_insertion_precedes_comments_attached_to_first_header(self):
        self.capture()
        self.codex.write_bytes(b'model = "fixture-model"\n\n# Profile notes\n[profiles.a]\nmodel = "nested"\n')
        self.manager().restore()
        self.assertEqual(self.codex.read_bytes(),
                         b'model = "fixture-model"\n"model_verbosity" = "low"\n'
                         b'\n# Profile notes\n[profiles.a]\nmodel = "nested"\n')

    def test_snapshot_version_actions_and_missing_destination_rejected(self):
        self.capture()
        baseline = self.manager().data.read_bytes()
        for change in (lambda s: s.update(manifestVersion=True),
                       lambda s: s.update(manifestVersion=999),
                       lambda s: s["targets"]["claude"][0].update(action="set", value=None),
                       lambda s: s["targets"]["claude"][0].update(action="delete")):
            snapshot = json.loads(baseline)
            change(snapshot)
            self.manager().data.write_bytes(ai.encode(snapshot))
            before = self.tree()
            with self.assertRaises(ai.SettingsError):
                self.manager().restore()
            self.assertEqual(self.tree(), before)
        self.manager().data.write_bytes(baseline)
        self.codex.unlink()
        before = self.tree()
        with self.assertRaisesRegex(ai.SettingsError, "missing-target"):
            self.manager().restore()
        self.assertEqual(self.tree(), before)

    def test_replace_failure_rollback_and_rollback_failure_are_reported(self):
        self.capture()
        self.mutate()
        original = ai.replace
        before = self.claude.read_bytes()

        def locked(path, raw):
            if path == self.codex:
                raise PermissionError("private exception " + CANARY)
            original(path, raw)

        manager = self.manager()
        with patch.object(ai, "replace", locked), self.assertRaises(ai.SettingsError):
            manager.restore()
        self.assertEqual(self.claude.read_bytes(), before)
        self.assertIn("rolled-back", [i["outcome"] for i in manager.result["items"]])
        counter = 0

        def failed_rollback(path, raw):
            nonlocal counter
            if path == self.claude:
                counter += 1
                if counter > 1:
                    raise PermissionError(CANARY)
            locked(path, raw)

        manager = self.manager()
        with patch.object(ai, "replace", failed_rollback), self.assertRaises(ai.SettingsError):
            manager.restore()
        self.assertIn("rollback-failed", [i["outcome"] for i in manager.result["items"]])

    def test_preflight_malformed_second_target_writes_nothing(self):
        self.capture()
        self.mutate()
        self.codex.write_bytes(b'model="unterminated ' + CANARY.encode())
        before = self.tree()
        run, result = self.cli("restore", "--force")
        self.assertEqual(run.returncode, 1)
        self.assertEqual(result["error"], "malformed-toml")
        self.assertEqual(self.tree(), before)
        self.assertNotIn(CANARY, run.stdout + run.stderr)

    def test_capture_invalid_missing_null_and_incomplete_snapshot_preserve_previous(self):
        self.capture()
        baseline = self.manager().data.read_bytes()
        for bad in [b'{"model": null}', b'{"cleanupPeriodDays": false}', b'{"autoCompactWindow": 1}',
                    b'{"model": {}}', b'{"env": "invalid parent"}', b'{"a":1,"a":2}', b'{']:
            with self.subTest(bad=bad):
                self.claude.write_bytes(bad)
                run, _ = self.cli("capture")
                self.assertEqual(run.returncode, 1)
                self.assertEqual(self.manager().data.read_bytes(), baseline)
        self.claude.unlink()
        run, _ = self.cli("capture")
        self.assertEqual(run.returncode, 1)
        self.assertEqual(self.manager().data.read_bytes(), baseline)
        self.claude.write_bytes(b'{}')
        snapshot = json.loads(baseline)
        snapshot["targets"]["claude"].pop()
        self.manager().data.write_bytes(ai.encode(snapshot))
        before = self.tree()
        with self.assertRaisesRegex(ai.SettingsError, "incomplete-snapshot"):
            self.manager().restore()
        self.assertEqual(self.tree(), before)

    def test_explicit_removal_round_trip_and_unset_not_null(self):
        self.claude.write_bytes(b'{}')
        self.codex.write_bytes(b'# comment\n[profiles.fixture]\nmodel="nested"\n')
        self.capture()
        self.claude.write_bytes(b'{"model":"remove-me","env":{"MAX_MCP_OUTPUT_TOKENS":"50000","OTHER":"keep"}}')
        self.codex.write_bytes(b'model="remove-me"\n# comment\n[profiles.fixture]\nmodel="nested"\n')
        self.manager().restore()
        self.assertEqual(json.loads(self.claude.read_bytes()), {"env": {"OTHER": "keep"}})
        self.assertEqual(self.codex.read_bytes(), b'# comment\n[profiles.fixture]\nmodel="nested"\n')
        self.assertFalse(self.manager().restore()["changed"])

    def test_canaries_no_capture_output_errors_or_repo_hits(self):
        self.claude.write_bytes(ai.encode({"env": {"ANTHROPIC_AUTH_TOKEN": CANARY},
                                         "mcpServers": {"x": {"headers": {"Authorization": CANARY}}}}))
        self.codex.write_bytes(('model="fixture-model"\nunknown="' + CANARY + '"\n[mcp_servers.x]\nheaders={Authorization="' + CANARY + '"}\n').encode())
        (self.root / "desktop.json").write_text(CANARY)
        for command in ("capture", "status", "restore"):
            run, result = self.cli(command, "--force")
            self.assertEqual(run.returncode, 0)
            self.assertNotIn(CANARY, run.stdout + run.stderr)
            self.assertIn("claude-desktop", result["coverage"]["notInspected"])
        self.assertNotIn(CANARY.encode(), self.manager().data.read_bytes())
        self.claude.write_bytes(ai.encode({"model": CANARY}))
        run, _ = self.cli("capture")
        self.assertEqual(run.returncode, 1)
        self.assertNotIn(CANARY, run.stdout + run.stderr)
        # Only the simulated repo (not private source profiles/backups) is publication scope.
        self.assertFalse(any(CANARY.encode() in p.read_bytes() for p in self.manager().data.parent.rglob("*") if p.is_file()))

    def test_unavailable_status_is_attention_and_does_not_write(self):
        self.claude.unlink()
        self.codex.write_bytes(b'invalid')
        before = self.tree()
        run, result = self.cli("status")
        self.assertEqual(run.returncode, 0)
        self.assertEqual(len(result["attention"]), 3)
        self.assertEqual(self.tree(), before)

    def test_codex_running_stub_force_and_whatif(self):
        self.capture()
        self.mutate()
        before = self.tree()
        manager = self.manager(codex_running=lambda: True)
        with self.assertRaisesRegex(ai.SettingsError, "codex-running"):
            manager.restore()
        with self.assertRaisesRegex(ai.SettingsError, "codex-running"):
            manager.restore(what_if=True)
        self.assertEqual(self.tree(), before)
        manager.restore(force=True)

    def test_sandbox_rejects_live_like_outside_paths_and_symlink_escape(self):
        for kwargs in ({"claude_home": self.root.parent / ".claude"},
                       {"codex_home": Path.home() / ".codex"},
                       {"data_path": self.claude}, {"backup_root": self.root / "repo" / "backups"}):
            with self.subTest(kwargs=kwargs), self.assertRaises(ai.SettingsError):
                self.manager(**kwargs)
        with self.assertRaises(ai.SettingsError):
            ai.Manager(Path(tempfile.gettempdir()), MANIFEST)
        link = self.root / "linked"
        try:
            link.symlink_to(self.root / "claude", target_is_directory=True)
        except OSError:
            return  # Windows non-developer accounts may not create links.
        with self.assertRaises(ai.SettingsError):
            self.manager(claude_home=link)

    def assert_overlap_refused(self, command, *args):
        before = self.tree()
        directories = {p.relative_to(self.root) for p in self.root.rglob("*") if p.is_dir()}
        run, result = self.cli(command, *args)
        self.assertEqual(run.returncode, 1)
        self.assertEqual(result["error"], "overlapping-sandbox-paths")
        self.assertFalse(result["changed"])
        self.assertEqual(self.tree(), before)
        self.assertEqual({p.relative_to(self.root) for p in self.root.rglob("*") if p.is_dir()}, directories)

    def test_data_file_inside_codex_home_is_refused_without_writes(self):
        self.assert_overlap_refused("capture", "--data-path", str(self.codex.parent / "preferences.json"))

    def test_backup_directory_inside_claude_home_is_refused_without_writes(self):
        self.capture()
        self.mutate()
        self.assert_overlap_refused("restore", "--backup-root", str(self.claude.parent / "bk"))

    def test_shared_profile_home_is_refused_without_writes(self):
        (self.claude.parent / "config.toml").write_bytes(self.codex.read_bytes())
        self.assert_overlap_refused("capture", "--codex-home", str(self.claude.parent))

    def test_nested_data_file_inside_claude_home_is_refused_without_writes(self):
        self.assert_overlap_refused("capture", "--data-path", str(self.claude.parent / "repo" / "preferences.json"))

    def test_no_profile_reads_outside_sandbox_even_with_hostile_environment(self):
        visited = []
        original = Path.read_bytes

        def guarded(path):
            visited.append(path)
            self.assertTrue(path.resolve().is_relative_to(self.root))
            return original(path)

        with patch.dict(os.environ, {"CODEX_HOME": "X:/live-codex", "CLAUDE_CONFIG_DIR": "X:/live-claude"}), patch.object(Path, "read_bytes", guarded):
            self.capture()
            self.manager().status()
            self.manager().restore(what_if=True)
        self.assertTrue(visited)

    def test_no_git_index_changes_by_capture(self):
        repo = self.root / "repo"
        repo.mkdir()
        subprocess.run(["git", "init", "--quiet", str(repo)], check=True, capture_output=True)
        before = subprocess.run(["git", "-C", str(repo), "ls-files", "--stage"], capture_output=True, check=True).stdout
        self.capture()
        after = subprocess.run(["git", "-C", str(repo), "ls-files", "--stage"], capture_output=True, check=True).stdout
        self.assertEqual(before, after)
        self.assertEqual(list((repo / ".git" / "refs" / "heads").iterdir()), [])

    def test_private_backups_keep_five_completed_and_all_failed_runs(self):
        self.capture()
        for _ in range(7):
            self.mutate()
            self.manager().restore()
        manager = self.manager()
        self.assertEqual(len(list(manager.backups.glob("*/complete.json"))), 5)
        failed = manager.backups / "failed-fixture"
        ai.private_dir(failed)
        (failed / "settings.json").write_text(CANARY)
        self.mutate()
        self.manager().restore()
        self.assertTrue(failed.is_dir())
        if os.name != "nt":
            self.assertEqual(manager.backups.stat().st_mode & 0o777, 0o700)
        else:
            # No inherited ACE, and no grant to Everyone or Users.
            result = subprocess.run(["icacls", str(manager.backups)], capture_output=True, text=True, check=True)
            self.assertNotIn("(I)", result.stdout)
            self.assertNotIn("S-1-1-0", result.stdout)

    @unittest.skipUnless(os.name == "nt", "Windows ACL semantics")
    def test_existing_backup_directory_explicit_grants_are_removed(self):
        backup_root = self.manager().backups
        backup_root.mkdir()
        subprocess.run(["icacls", str(backup_root), "/grant", "*S-1-1-0:(OI)(CI)R"], capture_output=True, check=True)
        ai.private_dir(backup_root)
        # PowerShell's ACL API returns identities independently of localized icacls labels.
        command = "$a=Get-Acl -LiteralPath $env:AI_SETTINGS_FIXTURE_ACL; @($a.Access).Count; $a.AreAccessRulesProtected"
        result = subprocess.run(["pwsh", "-NoProfile", "-Command", command], capture_output=True, text=True,
                                env={**os.environ, "AI_SETTINGS_FIXTURE_ACL": str(backup_root)}, check=True)
        self.assertEqual(result.stdout.splitlines(), ["1", "True"])

    def test_manifest_checker_counts_and_negative_cases(self):
        counts = ai.validate_manifest(MANIFEST)
        self.assertEqual(counts, {"owned": 24, "ignored": 18, "inspectionSpaces": 2})
        variants = []
        def case(change):
            manifest = copy.deepcopy(MANIFEST)
            change(manifest)
            variants.append(manifest)
        case(lambda m: m.update(version=True))
        case(lambda m: m["targets"].update(unknown=m["targets"]["claude"]))
        case(lambda m: m["targets"]["claude"]["owned"].append(m["targets"]["claude"]["owned"][0]))
        case(lambda m: m["targets"]["claude"]["ignored"].append({"path": ["env"], "reason": "overlap"}))
        case(lambda m: m["targets"]["codex"]["owned"][0].update(type="table"))
        case(lambda m: m["targets"]["codex"]["owned"][0].update(path=["nested", "model"]))
        case(lambda m: m["targets"]["claude"]["owned"][4].update(min=100, max=1))
        case(lambda m: m["targets"]["claude"]["owned"][0].update(pattern="["))
        case(lambda m: m["targets"]["claude"]["owned"][0].update(unknown="rule"))
        case(lambda m: m["targets"]["claude"]["inspect"].append(["nested"]))
        case(lambda m: m["targets"]["claude"]["owned"][0].update(securityRelevant="yes"))
        case(lambda m: m["targets"]["claude"]["owned"][1].update(values=[]))
        for index, variant in enumerate(variants):
            with self.subTest(index=index), self.assertRaises(ai.SettingsError):
                ai.validate_manifest(variant)


if __name__ == "__main__":
    unittest.main(verbosity=2)
