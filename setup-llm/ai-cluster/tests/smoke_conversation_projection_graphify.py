"""Opt-in real Graphify smoke. Use its installed Python and matching CLI on PATH."""

import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import sys
import unittest

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("projection", Path(__file__).resolve().parents[2] / "scripts" / "conversation_projection.py")
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)


class InstalledGraphifySmoke(unittest.TestCase):
    def test_real_build_retrieval_replay_correction_removal(self):
        selected = json.loads((Path(__file__).parent / "fixtures" / "conversation-selection.json").read_text())
        with tempfile.TemporaryDirectory(prefix="conversation-graphify-smoke-") as directory:
            root = Path(directory).resolve() / "projection"
            result = p.run(root, selected)
            self.assertEqual(result["status"], "supported")
            version = subprocess.run(["graphify", "--version"], capture_output=True, text=True, check=True, timeout=30)
            self.assertEqual(version.stdout.strip(), "graphify " + result["graphifyVersion"])
            graph_path = root / "graph.json"
            original = json.loads(graph_path.read_text())
            for target, relation in (("branch:parent", "forked_from"), ("source:synthetic-source", "attached_source")):
                query = subprocess.run(["graphify", "path", "branch:child", target, "--graph", str(graph_path), "--directed"], capture_output=True, text=True, check=True, timeout=30)
                self.assertIn(relation, query.stdout)
            self.assertTrue((root / "cache" / "last_query_stamp").exists())
            self.assertEqual(p.run(root)["status"], "supported")
            self.assertFalse((root / "cache").exists())
            self.assertEqual(original, json.loads(graph_path.read_text()))
            corrected = copy.deepcopy(selected)
            corrected["revision"] = 2
            corrected["branches"][1]["sourceRevision"] = 2
            corrected["branches"][1]["summaries"][0]["text"] = "Corrected synthetic decision."
            self.assertEqual(p.run(root, corrected)["status"], "supported")
            self.assertNotIn("Use the existing tools", graph_path.read_text())
            self.assertIn("Corrected synthetic decision.", graph_path.read_text())
            corrected.update(revision=3, branches=[], exclude=["parent", "child"])
            self.assertEqual(p.run(root, corrected)["status"], "supported")
            self.assertEqual(json.loads(graph_path.read_text())["nodes"], [])
            self.assertEqual(p.run(root)["status"], "supported")
            self.assertEqual(json.loads(graph_path.read_text())["nodes"], [])
            with self.assertRaisesRegex(p.ProjectionError, "selection-stale"):
                p.run(root, selected)


if __name__ == "__main__":
    unittest.main()
