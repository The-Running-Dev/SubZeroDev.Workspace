"""Synthetic lifecycle tests; no Graphify install, network or personal sources needed."""

import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import sys
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "conversation_projection.py"
spec = importlib.util.spec_from_file_location("projection", SCRIPT)
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)


def fixture():
    return {"schemaVersion": 1, "corpusId": "synthetic-test", "revision": 1, "branches": [
        {"branchId": "parent", "sourceRevision": 1, "sources": [], "summaries": []},
        {"branchId": "child", "sourceRevision": 1, "parentBranchId": "parent", "sources": [{"refId": "fixture", "sha256": "a" * 64}], "summaries": [{"summaryId": "decision", "role": "assistant", "kind": "summary", "approved": True, "text": "Use the existing tools.", "memoryRef": "reviewed-example"}]}]}


def fake_builder(data, path):
    path.write_text(json.dumps({"nodes": data["nodes"], "links": data["edges"]}), encoding="utf-8")
    return "synthetic"


class ProjectionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        # macOS /var is an OS symlink. Use its canonical temp directory so the
        # production symlink/junction refusal remains exercised, not weakened.
        self.base = Path(self.temp.name).resolve()
        self.root = self.base / "projection"

    def run_projection(self, selected=None, builder=fake_builder):
        return p.run(self.root, selected, builder)

    def graph(self):
        return json.loads((self.root / "graph.json").read_text(encoding="utf-8"))

    def test_parent_attachment_summary_attribution_and_provenance(self):
        self.assertEqual(self.run_projection(fixture())["status"], "supported")
        graph = self.graph()
        self.assertEqual({(e["source"], e["target"], e["relation"]) for e in graph["links"]}, {
            ("branch:child", "branch:parent", "forked_from"),
            ("branch:child", "source:fixture", "attached_source"),
            ("branch:child", "branch:child:summary:decision", "approved_summary")})
        summary = next(n for n in graph["nodes"] if n.get("kind") == "summary")
        self.assertEqual((summary["role"], summary["sourceRevision"], summary["memoryRef"]), ("assistant", 1, "reviewed-example"))
        self.assertTrue(all(e["projectionSchemaVersion"] == 1 and e["corpusId"] == "synthetic-test" and e["source_file"] == "selected:synthetic-test" for e in graph["links"]))

    def test_replay_and_rebuild_are_identical(self):
        self.run_projection(fixture())
        first = self.graph()
        self.run_projection(fixture())
        self.assertEqual(first, self.graph())
        self.run_projection()
        self.assertEqual(first, self.graph())

    def test_correction_replaces_derived_text(self):
        value = fixture()
        self.run_projection(value)
        value["revision"] = 2
        value["branches"][1]["sourceRevision"] = 2
        value["branches"][1]["summaries"][0]["text"] = "Use the corrected tools."
        self.run_projection(value)
        text = (self.root / "graph.json").read_text(encoding="utf-8")
        self.assertNotIn("Use the existing tools.", text)
        self.assertIn("Use the corrected tools.", text)

    def test_large_accepted_selection_can_rebuild_and_remove_expanded_state(self):
        value = {"schemaVersion": 1, "corpusId": "large-synthetic", "revision": 1, "branches": [
            {"branchId": f"branch-{i}", "sourceRevision": 1, "sources": [], "summaries": [
                {"summaryId": "first", "role": "assistant", "kind": "summary", "approved": True, "text": "x" * 2000},
                {"summaryId": "second", "role": "assistant", "kind": "summary", "approved": True, "text": "y" * 1880}]} for i in range(500)]}
        selected = self.base / "selected.json"
        selected.write_text(p.canonical(value), encoding="utf-8")
        self.assertLessEqual(selected.stat().st_size, 2 * 1024 * 1024)
        self.assertEqual(self.run_projection(p.read_json(selected, max_bytes=2 * 1024 * 1024))["status"], "supported")
        self.assertGreater((self.root / "state.json").stat().st_size, 2 * 1024 * 1024)
        self.assertGreater((self.root / "graph.json").stat().st_size, 2 * 1024 * 1024)
        self.assertEqual(self.run_projection()["status"], "supported")
        value.update(revision=2, branches=[])
        self.assertEqual(self.run_projection(value)["status"], "supported")
        self.assertEqual(self.graph()["nodes"], [])
        self.assertEqual(self.run_projection()["status"], "supported")
        self.assertEqual(len(p.read_json(self.root / "state.json")["tombstones"]), 500)

    def test_external_selection_remains_size_limited(self):
        selected = self.base / "oversized.json"
        selected.write_text("x" * (2 * 1024 * 1024 + 1))
        with self.assertRaisesRegex(p.ProjectionError, "input-unreadable"):
            p.read_json(selected, max_bytes=2 * 1024 * 1024)

    def test_correction_requires_source_revision_and_rejects_regression(self):
        value = fixture()
        self.run_projection(value)
        value["revision"] = 2
        value["branches"][1]["summaries"][0]["text"] = "Corrected."
        with self.assertRaisesRegex(p.ProjectionError, "source-revision-conflict"):
            self.run_projection(value)
        value["branches"][1]["sourceRevision"] = 2
        self.run_projection(value)
        value["revision"] = 3
        value["branches"][1]["sourceRevision"] = 1
        with self.assertRaisesRegex(p.ProjectionError, "source-stale"):
            self.run_projection(value)

    def test_deletion_exclusion_and_stale_reindex_cannot_resurrect(self):
        original = fixture()
        self.run_projection(original)
        removed = fixture()
        removed.update(revision=2, branches=[], exclude=["never-indexed"])
        self.run_projection(removed)
        self.assertEqual(self.graph()["nodes"], [])
        self.run_projection()
        self.assertEqual(self.graph()["nodes"], [])
        with self.assertRaisesRegex(p.ProjectionError, "selection-stale"):
            self.run_projection(original)
        stale = fixture()
        stale["revision"] = 3
        with self.assertRaisesRegex(p.ProjectionError, "explicit-restore-required"):
            self.run_projection(stale)
        self.assertEqual(json.loads((self.root / "state.json").read_text())["tombstones"], ["child", "never-indexed", "parent"])
        stale["restore"] = ["parent", "child"]
        self.run_projection(stale)
        self.assertTrue(self.graph()["nodes"])

    def test_excluded_ancestor_is_not_reintroduced_through_parent_edge(self):
        value = fixture()
        value["branches"] = [value["branches"][1]]
        value["exclude"] = ["parent"]
        self.run_projection(value)
        self.assertNotIn("branch:parent", {n["id"] for n in self.graph()["nodes"]})
        self.assertNotIn("forked_from", {e["relation"] for e in self.graph()["links"]})

    def test_build_failure_removes_stale_outputs_and_retries_persisted_selection(self):
        self.run_projection(fixture())
        value = fixture()
        value.update(revision=2, branches=[])
        def failed(data, path):
            path.write_text("partial")
            print("PRIVATE-DIAGNOSTIC-SENTINEL")
            raise RuntimeError("PRIVATE-ERROR-SENTINEL")
        capture = io.StringIO()
        with contextlib.redirect_stdout(capture), contextlib.redirect_stderr(capture):
            result = self.run_projection(value, failed)
        self.assertEqual(result["code"], "graphify-build-failed")
        self.assertEqual(capture.getvalue(), "")
        self.assertTrue((self.root / "state.json").is_file())
        self.assertTrue(all(not (self.root / f).exists() for f in p.DERIVED))
        self.run_projection()
        self.assertEqual(self.graph()["nodes"], [])

    def test_missing_optional_graphify_preserves_selection_and_clears_graph(self):
        self.run_projection(fixture())
        def absent(data, path):
            raise ModuleNotFoundError("graphify")
        self.assertEqual(self.run_projection(builder=absent)["code"], "graphify-not-installed")
        self.assertFalse((self.root / "graph.json").exists())
        self.run_projection()
        self.assertTrue(self.graph()["nodes"])

    def test_raw_prompt_unknown_fields_and_unapproved_text_never_reach_builder(self):
        variants = []
        for key in ("raw", "prompt", "archivePath", "receipts", "handoff", "embeddingIdentity"):
            v = fixture()
            v[key] = "PRIVATE-RAW-SENTINEL"
            variants.append(v)
        for kind in ("exact", "suggestion", "unavailable"):
            v = fixture()
            v["branches"][1]["summaries"][0]["kind"] = kind
            variants.append(v)
        v = fixture()
        v["branches"][1]["summaries"][0]["approved"] = False
        variants.append(v)
        for value in variants:
            with self.subTest(value=value), patch.object(p, "build_graph") as builder:
                with self.assertRaises(p.ProjectionError):
                    self.run_projection(value, builder)
                builder.assert_not_called()
        self.assertFalse((self.root / "state.json").exists())

    def test_secret_shaped_summary_rejected_with_fixed_error(self):
        value = fixture()
        value["branches"][1]["summaries"][0]["text"] = "password=PRIVATE-SECRET-SENTINEL"
        with self.assertRaisesRegex(p.ProjectionError, "^summary-rejected$"):
            self.run_projection(value)

    def test_unrelated_archive_is_never_read_or_changed(self):
        archive = self.base / "private-archive"
        archive.mkdir()
        raw = archive / "branch.json"
        raw.write_text("PRIVATE-RAW-SENTINEL")
        original = p.read_json
        def guarded(path):
            self.assertNotIn(archive, Path(path).parents)
            return original(path)
        with patch.object(p, "read_json", guarded):
            self.run_projection(fixture())
        self.assertEqual(raw.read_text(), "PRIVATE-RAW-SENTINEL")
        self.assertNotIn("PRIVATE-RAW-SENTINEL", "".join(f.read_text() for f in self.root.iterdir()))

    def test_unknown_files_are_preserved_and_not_deleted(self):
        self.run_projection(fixture())
        cache = self.root / "unowned-cache.json"
        cache.write_text("keep")
        with self.assertRaisesRegex(p.ProjectionError, "state-root-not-dedicated"):
            self.run_projection()
        self.assertEqual(cache.read_text(), "keep")

    def test_verified_query_stamp_is_invalidated_on_removal(self):
        self.run_projection(fixture())
        cache = self.root / "cache"
        cache.mkdir()
        (cache / "last_query_stamp").write_text("synthetic-stamp")
        value = fixture()
        value.update(revision=2, branches=[])
        self.run_projection(value)
        self.assertFalse(cache.exists())
        self.assertEqual(self.graph()["nodes"], [])

    def test_unknown_cache_is_preserved_and_refused(self):
        self.run_projection(fixture())
        cache = self.root / "cache"
        cache.mkdir()
        (cache / "unowned.json").write_text("keep")
        with self.assertRaisesRegex(p.ProjectionError, "unowned-cache"):
            self.run_projection()
        self.assertEqual((cache / "unowned.json").read_text(), "keep")

    def test_lock_prevents_concurrent_updates(self):
        self.run_projection(fixture())
        (self.root / "lock").write_text("")
        with self.assertRaisesRegex(p.ProjectionError, "projection-busy"):
            self.run_projection()
        self.assertTrue((self.root / "lock").exists())

    def test_symlink_is_rejected_without_touching_target(self):
        self.run_projection(fixture())
        target = self.base / "target.json"
        target.write_text("keep")
        graph = self.root / "graph.json"
        graph.unlink()
        try:
            graph.symlink_to(target)
        except OSError:
            self.skipTest("Symlink creation requires local privileges")
        with self.assertRaisesRegex(p.ProjectionError, "unsafe-path"):
            self.run_projection()
        self.assertEqual(target.read_text(), "keep")

    def test_revision_conflicts_corpus_changes_and_parent_cycles_rejected(self):
        self.run_projection(fixture())
        value = fixture()
        value["branches"] = []
        with self.assertRaisesRegex(p.ProjectionError, "revision-conflict"):
            self.run_projection(value)
        value["corpusId"] = "different-corpus"
        with self.assertRaisesRegex(p.ProjectionError, "state-incompatible"):
            self.run_projection(value)
        value = fixture()
        value["branches"][0]["parentBranchId"] = "child"
        with self.assertRaises(p.ProjectionError):
            self.run_projection(value)

    def test_cli_errors_do_not_log_input_or_traceback(self):
        selected = self.base / "selection.json"
        selected.write_text('{"raw":"PRIVATE-RAW-SENTINEL"}')
        capture = io.StringIO()
        with contextlib.redirect_stdout(capture), contextlib.redirect_stderr(capture):
            code = p.main(["--state-root", str(self.root), "--selection", str(selected)])
        self.assertEqual(code, 2)
        self.assertEqual(json.loads(capture.getvalue()), {"status": "error", "code": "selection-invalid"})


if __name__ == "__main__":
    unittest.main()
