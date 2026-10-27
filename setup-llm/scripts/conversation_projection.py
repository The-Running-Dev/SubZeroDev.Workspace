"""Selected conversation metadata -> existing Graphify. No archive discovery or LLM calls."""

import argparse
import contextlib
import copy
import hashlib
import importlib.metadata
import io
import json
import os
from pathlib import Path
import re
import sys

VERSION = 1
SLUG = re.compile(r"[a-z0-9][a-z0-9-]{0,63}\Z")
SECRET = re.compile(r"(?i)(-----BEGIN [A-Z ]*PRIVATE KEY|\b(?:sk-|ghp_|github_pat_)[A-Za-z0-9_\-]{12,}|(?:api[_-]?key|password|token)\s*[:=]\s*\S+)")
DERIVED = ("extraction.json", "graph.json", "receipt.json")
OWNED = {"state.json", "lock", *DERIVED, "state.json.tmp", "extraction.json.tmp", "graph.json.tmp", "receipt.json.tmp"}


class ProjectionError(Exception):
    """Only fixed codes cross the command's output boundary."""


def require(condition, code="selection-invalid"):
    if not condition:
        raise ProjectionError(code)


def fields(value, required, optional=()):
    require(isinstance(value, dict) and set(required) <= value.keys() <= set(required) | set(optional))


def slug(value):
    require(isinstance(value, str) and SLUG.fullmatch(value) is not None)


def positive(value):
    require(type(value) is int and value > 0)


def unique(values):
    require(len(values) == len(set(values)))


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n"


def digest(value):
    return hashlib.sha256(canonical(value).encode()).hexdigest()


def no_links(path):
    # Reject symlinks and Windows junctions before any read, replace or unlink.
    for part in (path, *path.parents):
        require(not part.is_symlink() and not (hasattr(part, "is_junction") and part.is_junction()), "unsafe-path")


def read_json(path, max_bytes=None):
    no_links(path)
    # Only the external selection has a 2 MiB cap. Owned state includes an
    # accumulating exclusion/high-water ledger; graph provenance also expands the
    # input. Never publish owned output that this reader would subsequently reject.
    require(path.is_file() and (max_bytes is None or path.stat().st_size <= max_bytes), "input-unreadable")
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, "duplicate-json-key")
            result[key] = value
        return result
    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=pairs)


def selection(value):
    fields(value, ("schemaVersion", "corpusId", "revision", "branches"), ("exclude", "restore"))
    require(type(value["schemaVersion"]) is int and value["schemaVersion"] == VERSION)
    slug(value["corpusId"])
    positive(value["revision"])
    branches = value["branches"]
    require(isinstance(branches, list) and len(branches) <= 500)
    source_hashes = {}
    for branch in branches:
        fields(branch, ("branchId", "sourceRevision", "sources", "summaries"), ("parentBranchId",))
        slug(branch["branchId"])
        positive(branch["sourceRevision"])
        if "parentBranchId" in branch:
            slug(branch["parentBranchId"])
            require(branch["parentBranchId"] != branch["branchId"])
        for key in ("sources", "summaries"):
            require(isinstance(branch[key], list) and len(branch[key]) <= 100)
        for source in branch["sources"]:
            fields(source, ("refId", "sha256"))
            slug(source["refId"])
            require(isinstance(source["sha256"], str) and re.fullmatch(r"[a-f0-9]{64}", source["sha256"]) is not None)
            require(source_hashes.get(source["refId"], source["sha256"]) == source["sha256"])
            source_hashes[source["refId"]] = source["sha256"]
        unique([source["refId"] for source in branch["sources"]])
        for summary in branch["summaries"]:
            fields(summary, ("summaryId", "role", "kind", "approved", "text"), ("memoryRef",))
            slug(summary["summaryId"])
            require(summary["role"] in ("user", "assistant", "unknown") and summary["kind"] == "summary" and summary["approved"] is True)
            require(isinstance(summary["text"], str) and 0 < len(summary["text"].strip()) <= 2000)
            require(not SECRET.search(summary["text"]) and not any(ord(c) < 32 and c not in "\n\t" for c in summary["text"]), "summary-rejected")
            if "memoryRef" in summary:
                slug(summary["memoryRef"])
        unique([summary["summaryId"] for summary in branch["summaries"]])
        branch["sources"].sort(key=lambda s: s["refId"])
        branch["summaries"].sort(key=lambda s: s["summaryId"])
    unique([branch["branchId"] for branch in branches])
    branches.sort(key=lambda b: b["branchId"])
    ids = {branch["branchId"] for branch in branches}
    for key in ("exclude", "restore"):
        require(isinstance(value.get(key, []), list))
        for item in value.get(key, []):
            slug(item)
        unique(value.get(key, []))
        value[key] = sorted(value.get(key, []))
    require(not ids.intersection(value["exclude"]) and set(value["restore"]) <= ids)
    # A selected ancestor must be acyclic; absent ancestors remain opaque metadata,
    # never resurrected as nodes by following references outside the selection.
    parents = {b["branchId"]: b.get("parentBranchId") for b in branches}
    for start in ids:
        seen = set()
        while start in parents:
            require(start not in seen)
            seen.add(start)
            start = parents[start]
    return value


def transition(previous, selected):
    selected = selection(copy.deepcopy(selected))
    if previous is None:
        previous = {"schemaVersion": VERSION, "corpusId": selected["corpusId"], "selection": None, "tombstones": [], "highWater": {}}
    require(previous["schemaVersion"] == VERSION and previous["corpusId"] == selected["corpusId"], "state-incompatible")
    old = previous["selection"]
    if old is not None:
        require(selected["revision"] >= old["revision"], "selection-stale")
        if selected["revision"] == old["revision"]:
            require(selected == old, "revision-conflict")
            return previous
    tombstones = set(previous["tombstones"])
    ids = {b["branchId"] for b in selected["branches"]}
    tombstones.update(b["branchId"] for b in (old or {"branches": []})["branches"] if b["branchId"] not in ids)
    tombstones.update(selected["exclude"])
    require(not (ids & tombstones) - set(selected["restore"]), "explicit-restore-required")
    tombstones.difference_update(selected["restore"])
    high = copy.deepcopy(previous["highWater"])
    for branch in selected["branches"]:
        key = branch["branchId"]
        stamp = {"revision": branch["sourceRevision"], "digest": digest(branch)}
        if key in high:
            require(stamp["revision"] >= high[key]["revision"], "source-stale")
            require(stamp["revision"] != high[key]["revision"] or stamp == high[key], "source-revision-conflict")
        high[key] = stamp
    return {"schemaVersion": VERSION, "corpusId": selected["corpusId"], "selection": selected, "tombstones": sorted(tombstones), "highWater": high}


def extraction(selected):
    nodes, edges = {}, []
    provenance = {"corpusId": selected["corpusId"], "projectionSchemaVersion": VERSION, "selectionRevision": selected["revision"], "selectionDigest": digest(selected), "embeddingIdentity": "none"}
    source_file = "selected:" + selected["corpusId"]
    def node(key, label, **attributes):
        nodes[key] = {"id": key, "label": label, "file_type": "concept", "source_file": source_file, **provenance, **attributes}
    def edge(a, b, relation, revision):
        edges.append({"source": a, "target": b, "relation": relation, "confidence": "EXTRACTED", "source_file": source_file, "sourceRevision": revision, **provenance})
    ids = {b["branchId"] for b in selected["branches"]}
    for branch in selected["branches"]:
        bid, rev = "branch:" + branch["branchId"], branch["sourceRevision"]
        node(bid, branch["branchId"], sourceRevision=rev)
        if branch.get("parentBranchId") in ids:
            edge(bid, "branch:" + branch["parentBranchId"], "forked_from", rev)
        for source in branch["sources"]:
            sid = "source:" + source["refId"]
            node(sid, source["refId"], sourceSha256=source["sha256"])
            edge(bid, sid, "attached_source", rev)
        for summary in branch["summaries"]:
            sid = bid + ":summary:" + summary["summaryId"]
            node(sid, summary["text"], role=summary["role"], kind=summary["kind"], sourceRevision=rev, **({"memoryRef": summary["memoryRef"]} if "memoryRef" in summary else {}))
            edge(bid, sid, "approved_summary", rev)
    return {"nodes": [nodes[k] for k in sorted(nodes)], "edges": sorted(edges, key=lambda e: (e["source"], e["target"], e["relation"])), **provenance}


def build_graph(data, path):
    # Only the selected extraction reaches Graphify. Neither discovery, root=archive,
    # prose extraction, a model backend, global index nor MemoryKit is invoked.
    from graphify.validate import assert_valid
    from graphify.build import build_from_json
    from graphify.export import to_json
    assert_valid(data)
    graph = build_from_json(copy.deepcopy(data), directed=True, dedup=False)
    graph.graph.update({k: data[k] for k in ("corpusId", "projectionSchemaVersion", "selectionDigest", "embeddingIdentity")})
    require(to_json(graph, {}, str(path), force=True, built_at_commit=data["selectionDigest"]), "graphify-export-failed")
    return importlib.metadata.version("graphifyy")


def atomic(path, data):
    temp = path.with_name(path.name + ".tmp")
    no_links(temp)
    with os.fdopen(os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), "w", encoding="utf-8", newline="\n") as stream:
        stream.write(canonical(data))
    os.replace(temp, path)


def invalidate(root):
    for name in (*DERIVED, *(n + ".tmp" for n in DERIVED)):
        path = root / name
        no_links(path)
        path.unlink(missing_ok=True)
    # Verified Graphify 0.9.91 path queries create only this stamp here. No
    # recursive cache deletion: unknown cache contents are refused before mutation.
    cache = root / "cache"
    if cache.exists():
        (cache / "last_query_stamp").unlink(missing_ok=True)
        cache.rmdir()


def run(root, selected=None, builder=build_graph):
    root = Path(os.path.abspath(root))
    no_links(root)
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    entries = list(root.iterdir())
    for path in entries:
        no_links(path)
        if path.name == "cache":
            require(path.is_dir(), "state-root-not-dedicated")
            for cached in path.iterdir():
                no_links(cached)
                require(cached.name == "last_query_stamp" and cached.is_file(), "unowned-cache")
        else:
            require(path.name in OWNED and path.is_file(), "state-root-not-dedicated")
    require(not entries or (root / "state.json").exists(), "state-missing")
    try:
        lock = os.open(root / "lock", os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError:
        raise ProjectionError("projection-busy") from None
    try:
        previous = read_json(root / "state.json") if (root / "state.json").exists() else None
        require(previous is not None or selected is not None, "selection-required")
        state = transition(previous, selected) if selected is not None else transition(previous, previous["selection"])
        # Commit exclusion/high-water state before attempting an optional adapter.
        # Every invocation clears old retrieval output, including failed rebuilds.
        atomic(root / "state.json", state)
        invalidate(root)
        data = extraction(state["selection"])
        atomic(root / "extraction.json", data)
        try:
            # Graphify diagnostics may contain selected text: discard them, even on error.
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                version = builder(data, root / "graph.json.tmp")
            graph = read_json(root / "graph.json.tmp")
            require(isinstance(graph, dict) and isinstance(graph.get("nodes"), list), "graphify-output-invalid")
            os.replace(root / "graph.json.tmp", root / "graph.json")
            receipt = {"schemaVersion": VERSION, "status": "supported", "selectionDigest": digest(state["selection"]), "graphSha256": hashlib.sha256((root / "graph.json").read_bytes()).hexdigest(), "graphifyVersion": version, "contextGraph": "unknown-owner", "memory": "agentkit-reviewed-extraction-only", "embeddingIdentity": "none"}
            atomic(root / "receipt.json", receipt)
            return {"status": "supported", "code": "projection-built", "graphifyVersion": version, "contextGraph": "unknown-owner"}
        except (ImportError, importlib.metadata.PackageNotFoundError):
            invalidate(root)
            return {"status": "unavailable", "code": "graphify-not-installed", "contextGraph": "unknown-owner"}
        except Exception:
            invalidate(root)
            return {"status": "unavailable", "code": "graphify-build-failed", "contextGraph": "unknown-owner"}
    finally:
        os.close(lock)
        (root / "lock").unlink()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state-root", required=True, help="Dedicated private disposable projection directory outside Git")
    parser.add_argument("--selection", help="Explicit reviewed metadata JSON; omit to rebuild the persisted selection")
    args = parser.parse_args(argv)
    try:
        # Fixed errors only: never print paths, input values, source text or tracebacks.
        selected = read_json(Path(os.path.abspath(args.selection)), max_bytes=2 * 1024 * 1024) if args.selection else None
        result = run(args.state_root, selected)
        print(canonical(result), end="")
        return 0 if result["status"] == "supported" else 3
    except ProjectionError as error:
        print(canonical({"status": "error", "code": str(error)}), end="")
    except Exception:
        print(canonical({"status": "error", "code": "projection-invocation-failed"}), end="")
    return 2


if __name__ == "__main__":
    sys.exit(main())
