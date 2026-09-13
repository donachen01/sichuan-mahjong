#!/usr/bin/env python3
"""Build and run explicitly chosen C# fixtures into a NEW immutable run folder."""
import argparse
import datetime
import hashlib
import json
import subprocess
import shutil
from pathlib import Path

from learning_quality import sha256


def save(path, value):
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write("\n")


def tree(project):
    files = set()
    for base in (project / "dotnet", project / "research/xiaolaoshi_deep_learning/local_video_checks"):
        for p in base.rglob("*"):
            if p.is_file() and p.suffix in {".cs", ".csproj", ".props", ".targets"} and not {"obj", "bin"}.intersection(p.relative_to(base).parts):
                files.add(p)
    for name in ("global.json", "NuGet.config", "Directory.Build.props", "Directory.Build.targets", "Directory.Packages.props"):
        if (project / name).is_file():
            files.add(project / name)
    manifest = {str(p.relative_to(project)): sha256(p) for p in sorted(files)}
    digest = hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()
    return manifest, digest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path)
    parser.add_argument("bundle", type=Path)
    parser.add_argument("fixture", type=Path)
    parser.add_argument("--run-id", required=True)
    args = parser.parse_args()
    project, bundle = args.project.resolve(), args.bundle.resolve()
    if not args.run_id or any(x not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_" for x in args.run_id):
        parser.error("run-id must contain only letters, digits, hyphen or underscore")
    run = bundle / "decision-runs" / args.run_id
    run.mkdir(parents=True, exist_ok=False)  # never rewrite baseline/candidate evidence
    fixture = json.loads(args.fixture.read_text(encoding="utf-8"))
    save(run / "input.json", fixture)
    files, source_hash = tree(project)
    runner = project / "research/xiaolaoshi_deep_learning/local_video_checks/LocalVideoChecks.csproj"
    command = ["dotnet", "build", str(runner), "--no-restore", "--nologo"]
    with (run / "build.log").open("x") as log:
        subprocess.run(command, cwd=project, stdout=log, stderr=subprocess.STDOUT, check=True)
    if tree(project)[1] != source_hash:
        raise ValueError("source changed during build; run is not promotable")
    binary = runner.parent / "bin/Debug/net10.0/SichuanMahjong.AI.Core.dll"
    runner_binary = runner.parent / "bin/Debug/net10.0/LocalVideoChecks.dll"
    rules = {p: value for p, value in files.items() if "/Rules/" in p}
    if not rules:
        raise ValueError("rules source manifest empty")
    # Preserve replayable binaries instead of referring to mutable bin/Debug.
    shutil.copytree(runner_binary.parent, run / "runtime")
    frozen_runner = run / "runtime" / runner_binary.name
    frozen_ai = run / "runtime" / binary.name
    version = {"source_files": files, "source_tree_sha256": source_hash,
               "assembly_sha256": sha256(binary), "runner_sha256": sha256(runner_binary),
               "rules_sha256": hashlib.sha256(json.dumps(rules, sort_keys=True).encode()).hexdigest(),
               "build_verified": True, "build_command": command,
               "assembly_artifact": {"path": str(frozen_ai.relative_to(bundle)), "sha256": sha256(frozen_ai)},
               "runner_artifact": {"path": str(frozen_runner.relative_to(bundle)), "sha256": sha256(frozen_runner)},
               "recorded_at": datetime.datetime.now(datetime.timezone.utc).isoformat()}
    save(run / "version.json", version)
    execute = ["dotnet", str(frozen_runner), str(run / "input.json"), str(run / "raw-report.json")]
    with (run / "runtime.log").open("x") as log:
        proc = subprocess.run(execute, cwd=project, stdout=log, stderr=subprocess.STDOUT)
    raw = json.loads((run / "raw-report.json").read_text())
    if tree(project)[1] != source_hash or sha256(binary) != version["assembly_sha256"] or sha256(runner_binary) != version["runner_sha256"]:
        raise ValueError("source/binary changed during execution; run is not promotable")
    if raw.get("assembly_sha256") != version["assembly_sha256"]:
        raise ValueError("executed AI assembly differs from built assembly")
    report = {**raw, **{k: version[k] for k in ("source_tree_sha256", "assembly_sha256", "rules_sha256", "runner_sha256")},
              "input_sha256": sha256(run / "input.json"), "command": execute,
              "version_manifest": {"path": str((run / "version.json").relative_to(bundle)), "sha256": sha256(run / "version.json")},
              "recorded_at": datetime.datetime.now(datetime.timezone.utc).isoformat()}
    save(run / "report.json", report)
    print(json.dumps({"ok": raw.get("ok") is True and proc.returncode == 0, "report": str(run / "report.json"),
                      "report_sha256": sha256(run / "report.json"), "input_sha256": report["input_sha256"]}, ensure_ascii=False))
    return 0 if raw.get("ok") is True and proc.returncode == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
