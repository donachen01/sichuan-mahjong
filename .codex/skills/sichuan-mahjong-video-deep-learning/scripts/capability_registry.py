#!/usr/bin/env python3
"""Validate or merge explicitly selected capability records; never erase conflicts.

Prints JSON only. To persist, the caller reviews the output and publishes a new
version; no automatic policy change, test execution, or global library scan.
"""
import argparse
import copy
import json
from pathlib import Path


def require(condition, message):
    if not condition:
        raise ValueError(message)


def text(value):
    return isinstance(value, str) and bool(value.strip())


def validate_registry(registry):
    require(registry.get("schema_version") == 1, "invalid capability schema")
    records = registry.get("capabilities")
    require(isinstance(records, list) and records, "empty capability registry")
    ids = set()
    for item in records:
        require(text(item.get("id")) and item["id"] not in ids, "duplicate/missing capability ID")
        ids.add(item["id"])
        for field in ("mechanism", "next_gap"):
            require(text(item.get(field)), f"capability missing {field}")
        for field in ("boundaries", "code_components"):
            require(isinstance(item.get(field), list) and item[field] and all(text(x) for x in item[field]), f"empty capability {field}")
        require(isinstance(item.get("evidence"), list) and item["evidence"], "capability lacks source evidence")
        sources = set()
        for source in item["evidence"]:
            for field in ("source_group_id", "video_id", "node_id", "basis"):
                require(text(source.get(field)), f"capability evidence missing {field}")
            key = (source["video_id"], source["node_id"])
            require(key not in sources, "duplicate video-node evidence")
            sources.add(key)
        for field in ("contradictions", "failure_cases"):
            require(isinstance(item.get(field), list), f"missing {field} review")
            record_ids = set()
            for case in item[field]:
                require(text(case.get("id")) and case["id"] not in record_ids, f"duplicate/missing {field} ID")
                record_ids.add(case["id"])
                require(text(case.get("description")) and text(case.get("evidence_ref")), f"untraced {field}")
                if field == "contradictions":
                    require(case.get("status") in {"unresolved", "resolved"}, "unclassified contradiction")
                    if case["status"] == "resolved":
                        require(text(case.get("resolution")), "resolved contradiction lacks reasoning")
    return {item["id"]: len({e["source_group_id"] for e in item["evidence"]}) for item in records}


def merge(existing, incoming):
    validate_registry(existing)
    validate_registry(incoming)
    result = copy.deepcopy(existing)
    by_id = {item["id"]: item for item in result["capabilities"]}
    for item in incoming["capabilities"]:
        if item["id"] not in by_id:
            result["capabilities"].append(copy.deepcopy(item))
            continue
        old = by_id[item["id"]]
        require(item["mechanism"] == old["mechanism"], "mechanism change needs explicit new revision, not last-video overwrite")
        for field in ("boundaries", "code_components"):
            old[field] = list(dict.fromkeys(old[field] + item[field]))
        for field in ("evidence", "contradictions", "failure_cases"):
            key = (lambda x: (x["video_id"], x["node_id"])) if field == "evidence" else (lambda x: x["id"])
            known = {key(x): x for x in old[field]}
            for addition in item[field]:
                if key(addition) in known:
                    require(known[key(addition)] == addition, f"conflicting {field}; explicit adjudication required")
                else:
                    old[field].append(copy.deepcopy(addition))
                    known[key(addition)] = addition
        if item["next_gap"] != old["next_gap"]:
            old["next_gap"] += "\n" + item["next_gap"]
    validate_registry(result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("registry", type=Path)
    parser.add_argument("--merge", type=Path)
    args = parser.parse_args()
    try:
        registry = json.loads(args.registry.read_text(encoding="utf-8"))
        if args.merge:
            registry = merge(registry, json.loads(args.merge.read_text(encoding="utf-8")))
        print(json.dumps({"ok": True, "independent_source_groups": validate_registry(registry), "registry": registry}, ensure_ascii=False, indent=2))
        return 0
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(json.dumps({"ok": False, "errors": [str(exc)]}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
