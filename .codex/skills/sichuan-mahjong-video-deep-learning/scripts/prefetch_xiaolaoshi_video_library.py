#!/usr/bin/env python3
"""Build a resumable, source-only local library for the Xiao Laoshi inventory.

This deliberately does *not* advance learning-run-state.json or change any
inventory learning status.  A downloaded source is evidence material, not a
completed lesson.  Each item lives in its own order/title/id directory so a
future offline learning pass can locate it without relying on a transient CDN
URL or browser session.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import os
import re
import signal
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import threading
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inventory", type=Path, required=True)
    parser.add_argument("--target-root", type=Path, required=True)
    parser.add_argument("--research-root", type=Path, required=True,
                        help="Existing evidence bundles; valid sources are copied, not fetched again.")
    parser.add_argument("--runtime-dir", type=Path, required=True)
    parser.add_argument("--state-file", type=Path,
                        help="Defaults to <target-root>/prefetch-state.json")
    parser.add_argument("--limit", type=int, default=0,
                        help="For a bounded run; 0 means all items.")
    parser.add_argument("--start-order", type=int, default=1)
    parser.add_argument("--parallel-downloads", type=int, default=1,
                        help="Concurrent downloads; each lane uses an isolated Chrome profile.")
    parser.add_argument("--capture-wait-ms", type=int, default=10000,
                        help="Maximum wait for the matching Douyin detail response.")
    parser.add_argument("--fail-fast", action="store_true")
    parser.add_argument("--download-attempts", type=int, default=3,
                        help="Attempts for transient network failures before recording one failed item.")
    parser.add_argument("--retry-delay-seconds", type=float, default=20.0)
    parser.add_argument("--download-timeout-seconds", type=float, default=600.0)
    parser.add_argument("--circuit-breaker-failures", type=int, default=5,
                        help="Pause after this many consecutive transient item failures; 0 disables it.")
    parser.add_argument("--circuit-breaker-sleep-seconds", type=float, default=300.0)
    return parser.parse_args()


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def atomic_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent,
                                     prefix=f".{path.name}.", suffix=".tmp", delete=False) as handle:
        json.dump(value, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")
        temporary = Path(handle.name)
    temporary.replace(path)


def read_json(path: Path, fallback: Any) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return fallback


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def playable(path: Path) -> bool:
    if not path.is_file() or path.stat().st_size <= 100_000:
        return False
    completed = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nokey=1:noprint_wrappers=1", str(path)],
        capture_output=True, text=True,
    )
    try:
        return completed.returncode == 0 and float(completed.stdout.strip()) > 0
    except ValueError:
        return False


def safe_fragment(value: str, limit: int = 72) -> str:
    value = re.sub(r'[\x00-\x1f<>:"/\\|?*]', " ", value)
    value = re.sub(r"\\s+", " ", value).strip(" .")
    return (value[:limit].rstrip(" .") or "untitled")


def item_directory(root: Path, item: dict[str, Any]) -> Path:
    order = int(item["order"])
    title = safe_fragment(str(item.get("title") or "untitled"))
    video_id = str(item["video_id"])
    return root / f"{order:05d}_{title}_{video_id}"


def existing_target_directory(root: Path, video_id: str) -> Path | None:
    """Accept a prior diagnostic/title variant, but only after media validation."""
    candidates = sorted(path for path in root.glob(f"*_{video_id}") if path.is_dir())
    for candidate in candidates:
        if is_valid_source(candidate / "source.mp4", candidate / "metadata.json", video_id):
            return candidate
    return None


def expected_hash(metadata: dict[str, Any]) -> str:
    return str(metadata.get("sha256") or metadata.get("source_sha256") or "").lower()


def is_valid_source(source: Path, metadata_path: Path, video_id: str) -> bool:
    if not playable(source):
        return False
    if not metadata_path.is_file():
        return False
    metadata = read_json(metadata_path, {})
    recorded_id = str(metadata.get("aweme_id") or metadata.get("video_id") or "")
    if recorded_id != video_id:
        return False
    recorded_hash = expected_hash(metadata)
    return bool(recorded_hash) and sha256_file(source) == recorded_hash


def copy_existing_source(existing_dir: Path, destination_dir: Path, video_id: str) -> bool:
    source = existing_dir / "source.mp4"
    metadata = existing_dir / "metadata.json"
    if not is_valid_source(source, metadata, video_id):
        return False
    destination_dir.mkdir(parents=True, exist_ok=True)
    temporary = destination_dir / ".source-copying.mp4"
    shutil.copy2(source, temporary)
    temporary.replace(destination_dir / "source.mp4")
    source_metadata = read_json(metadata, {})
    source_metadata["library_copied_at"] = utc_now()
    source_metadata["library_source"] = str(existing_dir)
    source_metadata["aweme_id"] = video_id
    source_metadata["file_name"] = "source.mp4"
    source_metadata["file_size"] = (destination_dir / "source.mp4").stat().st_size
    source_metadata["sha256"] = sha256_file(destination_dir / "source.mp4")
    atomic_json(destination_dir / "metadata.json", source_metadata)
    return True


def write_state(state_path: Path, state: dict[str, Any]) -> None:
    state["updated_at"] = utc_now()
    atomic_json(state_path, state)


ANSI_ESCAPE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
URL_QUERY = re.compile(r"(https?://[^\s?'\"\\]+)\?[^\s'\"\\]+")
TRANSIENT_MARKERS = (
    "ERR_CONNECTION_CLOSED",
    "ERR_CONNECTION_RESET",
    "ERR_TIMED_OUT",
    "ERR_NETWORK_CHANGED",
    "Client network socket disconnected",
    "ECONNRESET",
    "ETIMEDOUT",
    "Temporary failure in name resolution",
    "browser launch stage timed out",
    "Execution context was destroyed",
    "page.goto: Timeout",
)
LOGIN_REQUIRED_MARKER = "[DOUYIN_LOGIN_REQUIRED]"
LOGIN_BROWSER_REQUIRED_MARKER = "[DOUYIN_LOGIN_BROWSER_REQUIRED]"
DOUYIN_LOGIN_COOKIE_NAMES = (
    "sessionid",
    "sessionid_ss",
    "sid_guard",
    "uid_tt",
    "uid_tt_ss",
)

ACTIVE_DOWNLOAD_GROUPS: set[int] = set()
ACTIVE_DOWNLOAD_GROUPS_LOCK = threading.Lock()


def register_download_group(process_group_id: int) -> None:
    with ACTIVE_DOWNLOAD_GROUPS_LOCK:
        ACTIVE_DOWNLOAD_GROUPS.add(process_group_id)


def unregister_download_group(process_group_id: int) -> None:
    with ACTIVE_DOWNLOAD_GROUPS_LOCK:
        ACTIVE_DOWNLOAD_GROUPS.discard(process_group_id)


def signal_download_group(process_group_id: int, signum: int) -> None:
    try:
        os.killpg(process_group_id, signum)
    except ProcessLookupError:
        pass


def terminate_download_process(process: subprocess.Popen[str]) -> str:
    """Stop the downloader and all browser descendants; return captured output."""
    signal_download_group(process.pid, signal.SIGTERM)
    try:
        output, _ = process.communicate(timeout=3.0)
    except subprocess.TimeoutExpired:
        signal_download_group(process.pid, signal.SIGKILL)
        output, _ = process.communicate()
    return output or ""


def stop_active_download_groups(signum: int, _frame: object) -> None:
    with ACTIVE_DOWNLOAD_GROUPS_LOCK:
        groups = tuple(ACTIVE_DOWNLOAD_GROUPS)
    for process_group_id in groups:
        signal_download_group(process_group_id, signal.SIGTERM)
    time.sleep(0.5)
    for process_group_id in groups:
        signal_download_group(process_group_id, signal.SIGKILL)
    os._exit(128 + signum)


def sanitize_diagnostic(value: str) -> str:
    """Keep useful failure evidence without persisting cookies or signed CDN URLs."""
    value = ANSI_ESCAPE.sub("", value or "")
    value = URL_QUERY.sub(r"\1?<redacted>", value)
    sanitized_lines = []
    for line in value.splitlines():
        if "cookie:" in line.lower():
            sanitized_lines.append("[redacted cookie header]")
        else:
            sanitized_lines.append(line)
    return "\n".join(sanitized_lines)[-4000:]


def is_transient_failure(value: str) -> bool:
    return any(marker in value for marker in TRANSIENT_MARKERS)


def profile_has_douyin_login(profile_dir: Path) -> bool | None:
    """Return False for a clearly anonymous profile and None if it cannot be read.

    Cookie values are never read or copied.  This is only a cheap guard against
    opening hundreds of pages with a profile that has never been logged in.
    """
    cookies_path = profile_dir / "Default" / "Cookies"
    if not cookies_path.is_file():
        return False
    placeholders = ",".join("?" for _ in DOUYIN_LOGIN_COOKIE_NAMES)
    query = (
        "SELECT 1 FROM cookies WHERE host_key LIKE '%douyin.com' "
        f"AND name IN ({placeholders}) LIMIT 1"
    )
    try:
        connection = sqlite3.connect(f"file:{cookies_path}?mode=ro", uri=True, timeout=0.2)
        try:
            return connection.execute(query, DOUYIN_LOGIN_COOKIE_NAMES).fetchone() is not None
        finally:
            connection.close()
    except sqlite3.Error:
        return None


def sanitize_prior_state(state: dict[str, Any]) -> None:
    for record in state.get("items", {}).values():
        if isinstance(record, dict) and isinstance(record.get("error"), str):
            record["error"] = sanitize_diagnostic(record["error"])


def recover_interrupted_downloads(state: dict[str, Any]) -> None:
    """Return records left active by a killed/restarted worker to the retry queue."""
    interrupted_at = utc_now()
    for record in state.get("items", {}).values():
        if isinstance(record, dict) and record.get("status") == "downloading":
            record.update({
                "status": "failed",
                "failed_at": interrupted_at,
                "error": "previous download worker was interrupted; queued for retry",
            })
            record.pop("download_lane", None)


def queue_priority(item: dict[str, Any], state: dict[str, Any],
                   target_root: Path) -> tuple[int, int, int]:
    """Resume interrupted/failed work before rechecking verified local files."""
    video_id = str(item["video_id"])
    prior = state.get("items", {}).get(video_id, {})
    prior_status = prior.get("status") if isinstance(prior, dict) else None
    retry_priority = 0 if prior_status in {"failed", "downloading"} else 1
    recoverable_local = (
        retry_priority == 0
        and (item_directory(target_root, item) / "source.mp4").is_file()
    )
    return (0 if recoverable_local else 1), retry_priority, int(item["order"])


def profile_modal_url(profile_url: str, video_id: str) -> str:
    """Build a second exact-ID route without weakening source identity checks."""
    if not profile_url:
        return ""
    parsed = urlsplit(profile_url)
    query = dict(parse_qsl(parsed.query, keep_blank_values=True))
    query["modal_id"] = video_id
    query.setdefault("showTab", "post")
    return urlunsplit((parsed.scheme, parsed.netloc, parsed.path,
                       urlencode(query), parsed.fragment))


def run_download(command: list[str], args: argparse.Namespace) -> dict[str, Any]:
    returncode: int | None = None
    output = ""
    attempts_used = 0
    for attempt in range(1, max(1, args.download_attempts) + 1):
        attempts_used = attempt
        process = subprocess.Popen(
            command,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
        register_download_group(process.pid)
        try:
            timeout = args.download_timeout_seconds if args.download_timeout_seconds > 0 else None
            captured, _ = process.communicate(timeout=timeout)
            returncode = process.returncode
            output = sanitize_diagnostic(captured)
        except subprocess.TimeoutExpired:
            captured = terminate_download_process(process)
            output = sanitize_diagnostic(
                f"download timed out after {args.download_timeout_seconds:.0f}s\n{captured}"
            )
            returncode = None
        finally:
            if process.poll() is not None:
                # A failed Playwright launch can leave Chrome descendants alive
                # after the Node/Python leader exits.  The group is task-scoped.
                signal_download_group(process.pid, signal.SIGTERM)
            unregister_download_group(process.pid)

        succeeded = returncode == 0
        transient = is_transient_failure(output) or returncode is None
        if succeeded or not transient or attempt >= max(1, args.download_attempts):
            break
        time.sleep(max(0.0, args.retry_delay_seconds) * attempt)
    return {
        "returncode": returncode,
        "output": output,
        "attempts": attempts_used,
        "transient": is_transient_failure(output) or returncode is None,
        "login_required": (
            LOGIN_REQUIRED_MARKER in output
            or LOGIN_BROWSER_REQUIRED_MARKER in output
        ),
    }


def main() -> int:
    signal.signal(signal.SIGTERM, stop_active_download_groups)
    signal.signal(signal.SIGINT, stop_active_download_groups)
    args = parse_args()
    inventory = read_json(args.inventory, {})
    items = sorted(inventory.get("items", []), key=lambda item: int(item["order"]))
    if not items:
        raise SystemExit(f"No inventory items found in {args.inventory}")
    author_profile_url = str((inventory.get("author") or {}).get("profile_url") or "")

    target_root = args.target_root.resolve()
    target_root.mkdir(parents=True, exist_ok=True)
    state_path = (args.state_file or target_root / "prefetch-state.json").resolve()
    state = read_json(state_path, {
        "schema_version": 1,
        "purpose": "source-only prefetch; does not represent learning completion",
        "inventory": str(args.inventory.resolve()),
        "target_root": str(target_root),
        "started_at": utc_now(),
        "items": {},
    })
    state.setdefault("items", {})
    sanitize_prior_state(state)
    recover_interrupted_downloads(state)
    login_profile = args.runtime_dir / "chrome-profile"
    login_status = profile_has_douyin_login(login_profile)
    if login_status is False:
        state.update({
            "run_status": "blocked",
            "run_phase": "login_required",
            "login_status": "required",
            "login_profile_dir": str(login_profile.resolve()),
            "current_video_ids": [],
            "current_run_summary": {
                "already_valid": 0,
                "copied_existing": 0,
                "downloaded": 0,
                "failed": 0,
            },
        })
        state.pop("current_video_id", None)
        write_state(state_path, state)
        print("Douyin login is required in the dedicated downloader profile", flush=True)
        return 0
    state["run_status"] = "running"
    state["run_phase"] = "preparing_queue"
    state["login_status"] = "detected" if login_status else "unknown"
    state.pop("finished_at", None)
    write_state(state_path, state)

    downloader = Path(__file__).with_name("download_douyin_video.py")
    selected = [item for item in items if int(item["order"]) >= args.start_order]
    selected.sort(key=lambda item: queue_priority(item, state, target_root))
    if args.limit:
        selected = selected[:args.limit]

    summary = {"already_valid": 0, "copied_existing": 0, "downloaded": 0, "failed": 0}
    state["current_run_summary"] = dict(summary)
    state["last_progress_at"] = utc_now()
    consecutive_transient_failures = 0
    parallel_downloads = max(1, min(int(args.parallel_downloads), 4))
    state["parallel_downloads"] = parallel_downloads
    selected_index = 0
    stop_requested = False
    login_required = False

    with concurrent.futures.ThreadPoolExecutor(max_workers=parallel_downloads) as executor:
        while selected_index < len(selected) and not stop_requested:
            batch: list[dict[str, Any]] = []
            while selected_index < len(selected) and len(batch) < parallel_downloads:
                item = selected[selected_index]
                selected_index += 1
                video_id = str(item["video_id"])
                destination = item_directory(target_root, item)
                prior_destination = existing_target_directory(target_root, video_id)
                if prior_destination is not None:
                    destination = prior_destination
                source = destination / "source.mp4"
                metadata = destination / "metadata.json"
                record: dict[str, Any] = {
                    "order": int(item["order"]),
                    "video_id": video_id,
                    "title": str(item.get("title") or ""),
                    "directory": str(destination),
                }
                if is_valid_source(source, metadata, video_id):
                    record.update({"status": "available", "method": "existing_target", "checked_at": utc_now()})
                    summary["already_valid"] += 1
                    state["items"][video_id] = record
                    write_state(state_path, state)
                    continue

                existing = args.research_root / video_id
                if copy_existing_source(existing, destination, video_id):
                    record.update({"status": "available", "method": "copied_verified_research_source", "completed_at": utc_now()})
                    summary["copied_existing"] += 1
                    state["items"][video_id] = record
                    write_state(state_path, state)
                    continue

                lane = len(batch) + 1
                profile_name = "chrome-profile" if lane == 1 else f"chrome-profile-lane-{lane}"
                command = [
                    sys.executable, str(downloader), str(item["url"]),
                    "--output-dir", str(destination),
                    "--runtime-dir", str(args.runtime_dir),
                    "--profile-dir", str(args.runtime_dir / profile_name),
                    "--cdp-endpoint", "http://127.0.0.1:9223",
                    "--wait-ms", str(max(0, args.capture_wait_ms)),
                    "--media-stall-timeout-ms", "60000",
                    "--force",
                    "--title", str(item.get("title") or ""),
                ]
                fallback_url = profile_modal_url(author_profile_url, video_id)
                if fallback_url:
                    command.extend(["--fallback-page-url", fallback_url])
                record.update({
                    "status": "downloading",
                    "attempt": 1,
                    "download_started_at": utc_now(),
                    "download_lane": lane,
                })
                state["items"][video_id] = record
                batch.append({
                    "video_id": video_id,
                    "source": source,
                    "metadata": metadata,
                    "record": record,
                    "command": command,
                })

            if not batch:
                continue

            active_ids = [task["video_id"] for task in batch]
            state["run_phase"] = "downloading"
            state["current_video_ids"] = active_ids
            state["current_video_id"] = active_ids[0]
            write_state(state_path, state)
            futures = {
                executor.submit(run_download, task["command"], args): task
                for task in batch
            }
            batch_had_success = False
            batch_transient_failures = 0
            pending = set(futures)
            while pending:
                done, pending = concurrent.futures.wait(
                    pending, timeout=5.0,
                    return_when=concurrent.futures.FIRST_COMPLETED,
                )
                if not done:
                    state["worker_heartbeat_at"] = utc_now()
                    write_state(state_path, state)
                    continue
                for future in done:
                    task = futures[future]
                    video_id = task["video_id"]
                    record = task["record"]
                    try:
                        result = future.result()
                    except Exception as exc:  # defensive boundary around one worker lane
                        result = {
                            "returncode": None,
                            "output": sanitize_diagnostic(f"download worker failed: {exc}"),
                            "attempts": 1,
                            "transient": False,
                            "login_required": False,
                        }

                    if result["returncode"] == 0 and is_valid_source(task["source"], task["metadata"], video_id):
                        record.update({
                            "status": "available",
                            "method": "download_douyin_video",
                            "attempts": result["attempts"],
                            "completed_at": utc_now(),
                        })
                        record.pop("error", None)
                        summary["downloaded"] += 1
                        batch_had_success = True
                    elif result.get("login_required"):
                        record.update({
                            "status": "waiting_login",
                            "blocked_at": utc_now(),
                            "attempts": result["attempts"],
                            "error": "请打开下载器专用抖音窗口，完成登录并保持窗口开启",
                        })
                        login_required = True
                        stop_requested = True
                        state["run_status"] = "blocked"
                        state["run_phase"] = "login_required"
                        state["login_status"] = "required"
                    else:
                        error = result["output"]
                        if result["returncode"] == 0:
                            error = sanitize_diagnostic(
                                f"download completed but source validation failed\n{error}"
                            )
                        record.update({
                            "status": "failed",
                            "failed_at": utc_now(),
                            "attempts": result["attempts"],
                            "error": error,
                        })
                        summary["failed"] += 1
                        if result["transient"]:
                            batch_transient_failures += 1
                    state["items"][video_id] = record
                    active_ids.remove(video_id)
                    state["current_video_ids"] = active_ids
                    if active_ids:
                        state["current_video_id"] = active_ids[0]
                    else:
                        state.pop("current_video_id", None)
                    state["current_run_summary"] = dict(summary)
                    state["last_progress_at"] = utc_now()
                    write_state(state_path, state)
                    print(json.dumps({"summary": summary, "last": record}, ensure_ascii=False), flush=True)
                    if record["status"] == "failed" and args.fail_fast:
                        stop_requested = True

            if batch_had_success:
                consecutive_transient_failures = 0
            else:
                consecutive_transient_failures += batch_transient_failures

            if (args.circuit_breaker_failures > 0
                    and consecutive_transient_failures >= args.circuit_breaker_failures):
                state["run_phase"] = "network_backoff"
                state.pop("current_video_id", None)
                state["current_video_ids"] = []
                write_state(state_path, state)
                print(json.dumps({
                    "event": "transient_failure_circuit_breaker",
                    "consecutive_failures": consecutive_transient_failures,
                    "sleep_seconds": args.circuit_breaker_sleep_seconds,
                }, ensure_ascii=False), flush=True)
                time.sleep(max(0.0, args.circuit_breaker_sleep_seconds))
                consecutive_transient_failures = 0
                state["run_phase"] = "preparing_queue"
                write_state(state_path, state)

    state["last_run_summary"] = summary
    state["current_run_summary"] = summary
    state.pop("current_video_id", None)
    state["current_video_ids"] = []
    if login_required:
        state["blocked_at"] = utc_now()
        state["run_status"] = "blocked"
        state["run_phase"] = "login_required"
        state["login_status"] = "required"
        write_state(state_path, state)
        print(json.dumps({
            "event": "douyin_login_required",
            "summary": summary,
            "state_file": str(state_path),
        }, ensure_ascii=False))
        return 0
    state["finished_at"] = utc_now()
    state["run_status"] = "complete" if not summary["failed"] else "retrying_failures"
    state["run_phase"] = "complete" if not summary["failed"] else "retry_cycle_complete"
    write_state(state_path, state)
    print(json.dumps({"summary": summary, "state_file": str(state_path)}, ensure_ascii=False))
    return 1 if summary["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
