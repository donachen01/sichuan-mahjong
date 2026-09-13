#!/usr/bin/env python3
"""Download one public Douyin video into a durable evidence directory.

The browser-capture approach is adapted from crazyooo/douyin-video-downloader-skill
(MIT). This version accepts search modal_id URLs, keeps only non-secret metadata,
and downloads media inside the same Playwright context that resolved the video.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import textwrap
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
from urllib.parse import parse_qs, urlparse


PLAYWRIGHT_VERSION = "1.58.2"
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/136.0.0.0 Safari/537.36"
)
ALLOWED_MEDIA_HOST_SUFFIXES = (
    ".douyinvod.com",
    ".zjcdn.com",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("url", help="Douyin share, /video/, or search modal_id URL")
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--runtime-dir", type=Path, required=True)
    parser.add_argument("--profile-dir", type=Path,
                        help="Chrome profile directory; defaults to <runtime-dir>/chrome-profile")
    parser.add_argument("--cdp-endpoint",
                        help="Reuse an already-running dedicated Chrome through local CDP")
    parser.add_argument("--fallback-page-url",
                        help="Optional second page route, such as an author profile modal URL")
    parser.add_argument("--wait-ms", type=int, default=15000)
    parser.add_argument("--media-stall-timeout-ms", type=int, default=60000,
                        help="Abort a media candidate only after this long with no bytes received")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--media-url-file", type=Path,
                        help="Browser-captured media URL; bypass public headless capture")
    parser.add_argument("--audio-url-file", type=Path,
                        help="Optional browser-captured DASH audio URL to mux with --media-url-file")
    parser.add_argument("--media-urls-stdin", action="store_true",
                        help="Read a JSON object with video and optional audio CDN URLs from stdin")
    parser.add_argument("--expected-duration", type=float)
    parser.add_argument("--title", default="")
    parser.add_argument("--author", default="")
    parser.add_argument("--published-label", default="")
    return parser.parse_args()


def extract_video_id(url: str) -> str:
    parsed = urlparse(url)
    modal_id = parse_qs(parsed.query).get("modal_id", [""])[0]
    if modal_id.isdigit():
        return modal_id
    match = re.search(r"/video/(\d+)", url)
    if match:
        return match.group(1)
    raise SystemExit("No modal_id or /video/{id} was found in the supplied URL.")


def ensure_runtime(runtime_dir: Path) -> Path:
    node = shutil.which("node")
    npm = shutil.which("npm")
    if not node or not npm:
        raise SystemExit("node and npm are required")
    runtime_dir.mkdir(parents=True, exist_ok=True)
    package = runtime_dir / "node_modules" / "playwright" / "package.json"
    if not package.exists():
        if not (runtime_dir / "package.json").exists():
            # ``npm init -y`` derives the package name from the directory and
            # rejects useful private runtime names such as ``.runtime``.  This
            # directory is an internal cache, so write the minimal private
            # manifest deterministically instead of depending on its basename.
            (runtime_dir / "package.json").write_text(
                json.dumps({
                    "name": "sichuan-mahjong-video-runtime",
                    "private": True,
                    "version": "1.0.0",
                }, indent=2) + "\n",
                encoding="utf-8",
            )
        subprocess.run([npm, "install", f"playwright@{PLAYWRIGHT_VERSION}"],
                       cwd=runtime_dir, check=True)
    return Path(node)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def probe_video(path: Path) -> dict:
    completed = subprocess.run([
        "ffprobe", "-v", "error", "-show_entries",
        "format=duration,size:stream=index,codec_name,width,height,r_frame_rate",
        "-of", "json", str(path),
    ], check=True, capture_output=True, text=True)
    return json.loads(completed.stdout)


def download_captured_media_url(media_url: str, destination: Path) -> None:
    media_url = media_url.strip()
    parsed = urlparse(media_url)
    hostname = (parsed.hostname or "").lower()
    if parsed.scheme != "https" or not any(
        hostname.endswith(suffix) for suffix in ALLOWED_MEDIA_HOST_SUFFIXES
    ):
        allowed = ", ".join(f"*{suffix}" for suffix in ALLOWED_MEDIA_HOST_SUFFIXES)
        raise SystemExit(f"Rejected media locator outside allowed Douyin CDN hosts: {allowed}")
    curl = shutil.which("curl")
    if not curl:
        raise SystemExit("curl is required")
    subprocess.run([
        curl, "-L", "--fail", "--retry", "2", "--connect-timeout", "15",
        "--speed-time", "60", "--speed-limit", "1024", "-A", USER_AGENT,
        "-H", "Referer: https://www.douyin.com/", "-H", "Range: bytes=0-",
        "-o", str(destination), media_url,
    ], check=True)


def download_captured_media(url_file: Path, destination: Path) -> None:
    download_captured_media_url(url_file.read_text(encoding="utf-8"), destination)


def download_and_mux_captured_dash(video_url_file: Path, audio_url_file: Path,
                                   destination: Path) -> None:
    download_and_mux_captured_dash_urls(
        video_url_file.read_text(encoding="utf-8"),
        audio_url_file.read_text(encoding="utf-8"),
        destination,
    )


def download_and_mux_captured_dash_urls(video_url: str, audio_url: str,
                                        destination: Path) -> None:
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise SystemExit("ffmpeg is required to mux captured DASH video and audio")
    with tempfile.TemporaryDirectory(prefix="douyin-dash-") as temp_dir:
        temp_root = Path(temp_dir)
        video_path = temp_root / "video.mp4"
        audio_path = temp_root / "audio.mp4"
        muxed_path = temp_root / "muxed.mp4"
        download_captured_media_url(video_url, video_path)
        download_captured_media_url(audio_url, audio_path)
        subprocess.run([
            ffmpeg, "-v", "error", "-y", "-i", str(video_path), "-i", str(audio_path),
            "-map", "0:v:0", "-map", "1:a:0", "-c", "copy", "-movflags", "+faststart",
            str(muxed_path),
        ], check=True)
        shutil.move(str(muxed_path), destination)


def capture_and_download(video_url: str, expected_video_id: str, destination: Path,
                         runtime_dir: Path, profile_dir: Optional[Path], wait_ms: int,
                         expected_title: str,
                         fallback_page_url: Optional[str] = None,
                         media_stall_timeout_ms: int = 60000,
                         cdp_endpoint: Optional[str] = None) -> dict:
    destination = destination.resolve()
    runtime_dir = runtime_dir.resolve()
    node = ensure_runtime(runtime_dir)
    profile_dir = (profile_dir or runtime_dir / "chrome-profile").resolve()
    stream_helper = Path(__file__).with_name("douyin_stream_media.js").resolve()
    identity_helper = Path(__file__).with_name("douyin_page_identity.js").resolve()
    with tempfile.NamedTemporaryFile(prefix="douyin-result-", suffix=".json",
                                     delete=False) as handle:
        result_path = Path(handle.name)
    script = textwrap.dedent(
        f"""
        const fs = require('fs');
        const {{ chromium }} = require('playwright');
        const {{ streamMedia }} = require({json.dumps(str(stream_helper))});
        const {{ verifyPagePlayerIdentity }} = require({json.dumps(str(identity_helper))});

        const allowedMediaHostSuffixes = {json.dumps(ALLOWED_MEDIA_HOST_SUFFIXES)};
        const mediaStallTimeoutMs = {max(5000, int(media_stall_timeout_ms))};

        (async () => {{
          let context = null;
          let connectedBrowser = null;
          let ownsContext = false;
          let page = null;
          let detail = null;
          let browserUserAgent = {json.dumps(USER_AGENT)};
          let pagePlayerIdentityVerified = false;
          let verifiedPageSnapshot = null;
          const observedDetailIds = new Set();
          const observedMediaUrls = new Set();
          let result = {{ ok: false, pageUrl: '', pageTitle: '', attempts: [], pageRoutes: [] }};
          try {{
            if ({json.dumps(bool(cdp_endpoint))}) {{
              try {{
                connectedBrowser = await chromium.connectOverCDP(
                  {json.dumps(cdp_endpoint or '')}, {{ timeout: 30000 }}
                );
                const contexts = connectedBrowser.contexts();
                if (!contexts.length) throw new Error('dedicated Chrome has no browser context');
                context = contexts[0];
              }} catch (error) {{
                throw new Error(
                  '[DOUYIN_LOGIN_BROWSER_REQUIRED] open the downloader login window and keep it running: '
                  + String(error)
                );
              }}
            }} else {{
              ownsContext = true;
              context = await Promise.race([
                chromium.launchPersistentContext(
                  {json.dumps(str(profile_dir))}, {{
                    channel: 'chrome', headless: false,
                    timeout: 30000,
                    ignoreDefaultArgs: ['--enable-automation'],
                    args: [
                      '--disable-blink-features=AutomationControlled',
                      '--window-position=-32000,-32000',
                      '--window-size=800,600'
                    ]
                  }}
                ),
                new Promise((_, reject) => setTimeout(
                  () => reject(new Error('browser launch stage timed out after 30000ms')), 30000
                ))
              ]);
            }}
            await context.addInitScript(() => {{
              try {{
                Object.defineProperty(navigator, 'webdriver', {{ get: () => undefined }});
              }} catch (_) {{}}
            }});
            page = await context.newPage();
            try {{ browserUserAgent = await page.evaluate(() => navigator.userAgent); }} catch (_) {{}}
            page.on('request', request => {{
              try {{
                const candidate = new URL(request.url());
                if (allowedMediaHostSuffixes.some(suffix => candidate.hostname.endsWith(suffix))) {{
                  observedMediaUrls.add(request.url());
                }}
              }} catch (_) {{}}
            }});
            page.on('response', async (response) => {{
              const responseUrl = response.url();
              if (responseUrl.includes('/aweme/v1/web/aweme/detail/')) {{
                try {{
                  const candidate = await response.json();
                  const candidateId = String(
                    (candidate && candidate.aweme_detail && candidate.aweme_detail.aweme_id) || ''
                  );
                  if (candidateId) observedDetailIds.add(candidateId);
                  if (candidateId === {json.dumps(expected_video_id)}) detail = candidate;
                }} catch (_) {{}}
              }}
            }});
            const pageTargets = [{json.dumps(video_url)}, {json.dumps(fallback_page_url or '')}]
              .filter((value, index, values) => value && values.indexOf(value) === index);
            for (const pageTarget of pageTargets) {{
              detail = null;
              pagePlayerIdentityVerified = false;
              verifiedPageSnapshot = null;
              observedMediaUrls.clear();
              let navigationError = '';
              try {{
                await page.goto(pageTarget, {{ waitUntil: 'commit', timeout: 30000 }});
              }} catch (error) {{ navigationError = String(error); }}
              const detailDeadline = Date.now() + {int(wait_ms)};
              while (Date.now() < detailDeadline) {{
                if (detail) break;
                await page.waitForTimeout(250);
              }}
              let pageSnapshot = {{
                pageUrl: page.url(), pageTitle: '', htmlHasExpectedId: false,
                mediaCandidates: [], durationSeconds: 0, loginRequired: false
              }};
              try {{
                pageSnapshot = await page.evaluate(expectedId => {{
                  const videos = Array.from(document.querySelectorAll('video'));
                  const mediaCandidates = videos
                    .map(video => video.currentSrc || video.src || '')
                    .filter(Boolean);
                  const durationVideo = videos.find(video =>
                    Number.isFinite(video.duration) && video.duration > 0
                  );
                  const loginRequired = Array.from(document.querySelectorAll('button, a'))
                    .some(element => {{
                      const text = (element.textContent || '').trim();
                      if (text !== '登录') return false;
                      const style = getComputedStyle(element);
                      const bounds = element.getBoundingClientRect();
                      return style.display !== 'none' && style.visibility !== 'hidden'
                        && bounds.width > 0 && bounds.height > 0;
                    }});
                  return {{
                    pageUrl: location.href,
                    pageTitle: document.title,
                    htmlHasExpectedId: document.documentElement.innerHTML.includes(expectedId),
                    mediaCandidates,
                    durationSeconds: durationVideo ? durationVideo.duration : 0,
                    loginRequired,
                  }};
                }}, {json.dumps(expected_video_id)});
              }} catch (_) {{}}
              pagePlayerIdentityVerified = verifyPagePlayerIdentity({{
                pageUrl: pageSnapshot.pageUrl,
                pageTitle: pageSnapshot.pageTitle,
                expectedVideoId: {json.dumps(expected_video_id)},
                expectedTitle: {json.dumps(expected_title)},
                htmlHasExpectedId: pageSnapshot.htmlHasExpectedId,
                hasMediaCandidate: pageSnapshot.mediaCandidates.length > 0 || observedMediaUrls.size > 0,
              }});
              if (pagePlayerIdentityVerified) verifiedPageSnapshot = pageSnapshot;
              result.pageRoutes.push({{
                kind: pageTarget === {json.dumps(video_url)} ? 'canonical' : 'fallback',
                navigationError,
                matched: Boolean(detail),
                verifiedPagePlayer: pagePlayerIdentityVerified,
                loginRequired: Boolean(pageSnapshot.loginRequired)
              }});
              if (detail || pagePlayerIdentityVerified) break;
            }}
            result.pageUrl = page.url();
            try {{ result.pageTitle = await page.title(); }} catch (_) {{}}
            const aweme = (detail && detail.aweme_detail) || {{}};
            const detailIdentityVerified =
              String(aweme.aweme_id || '') === {json.dumps(expected_video_id)};
            if (!detailIdentityVerified && !pagePlayerIdentityVerified) {{
              if (result.pageRoutes.some(route => route.loginRequired)) {{
                throw new Error('[DOUYIN_LOGIN_REQUIRED] dedicated downloader profile is not logged in');
              }}
              throw new Error(
                `target aweme_id unavailable; routes=${{result.pageRoutes.length}} ` +
                `other_detail_ids=${{observedDetailIds.size}}`
              );
            }}
            const video = aweme.video || {{}};
            const candidates = [];
            const addUrl = value => {{
              if (value && !candidates.includes(value)) candidates.push(value);
            }};
            const addNode = node => {{
              for (const value of ((node || {{}}).url_list || []))
                addUrl(value);
            }};
            addNode(video.play_addr_h264);
            addNode(video.play_addr);
            for (const rate of (video.bit_rate || [])) addNode(rate.play_addr);
            const domVideos = verifiedPageSnapshot ? verifiedPageSnapshot.mediaCandidates : [];
            for (const value of domVideos) addUrl(value);
            for (const value of observedMediaUrls) addUrl(value);
            try {{
              await page.evaluate(() => {{
                for (const videoElement of document.querySelectorAll('video')) {{
                  videoElement.pause();
                }}
              }});
            }} catch (_) {{}}
            let media = null;
            for (const candidate of candidates.slice(0, 6)) {{
              try {{
                const cookies = await context.cookies(candidate);
                const cookieHeader = cookies.map(cookie => `${{cookie.name}}=${{cookie.value}}`).join('; ');
                const streamed = await streamMedia(candidate, {{
                  destination: {json.dumps(str(destination))},
                  allowedHostSuffixes: allowedMediaHostSuffixes,
                  stallTimeoutMs: mediaStallTimeoutMs,
                  responseTimeoutMs: 15000,
                  headers: {{
                    'User-Agent': browserUserAgent,
                    'Referer': result.pageUrl || 'https://www.douyin.com/',
                    'Range': 'bytes=0-',
                    'Accept-Encoding': 'identity',
                    ...(cookieHeader ? {{ 'Cookie': cookieHeader }} : {{}})
                  }}
                }});
                result.attempts.push(streamed);
                if ((streamed.status === 200 || streamed.status === 206) && streamed.bytes > 100000) {{
                  media = streamed;
                  break;
                }}
              }} catch (error) {{ result.attempts.push({{ error: String(error) }}); }}
            }}
            if (!media) throw new Error(
              `no usable media; detail=${{Boolean(detail && detail.aweme_detail)}} domVideos=${{domVideos.length}}`
            );
            const author = aweme.author || {{}};
            result.ok = true;
            result.metadata = {{
              aweme_id: detailIdentityVerified
                ? String(aweme.aweme_id || '')
                : {json.dumps(expected_video_id)},
              description: aweme.desc || {json.dumps(expected_title)},
              author: author.nickname || '',
              author_sec_uid: author.sec_uid || '',
              create_time: Number(aweme.create_time || 0),
              duration_ms: Number(
                (aweme.video || {{}}).duration ||
                ((verifiedPageSnapshot && verifiedPageSnapshot.durationSeconds || 0) * 1000)
              ),
              capture_source: detailIdentityVerified ? 'detail_api' : 'verified_page_player',
              page_url: result.pageUrl,
              source_url: {json.dumps(video_url)}
            }};
          }} catch (error) {{ result.error = String(error); }}
          finally {{
            fs.writeFileSync({json.dumps(str(result_path))}, JSON.stringify(result, null, 2));
            if (page) {{
              try {{ await page.close(); }} catch (_) {{}}
            }}
            if (context && ownsContext) {{
              try {{
                await Promise.race([
                  context.close(),
                  new Promise(resolve => setTimeout(resolve, 10000))
                ]);
              }} catch (_) {{}}
            }}
          }}
          process.exit(result.ok ? 0 : 2);
        }})();
        """
    )
    try:
        completed = subprocess.run([str(node), "-e", script], cwd=runtime_dir)
        result = json.loads(result_path.read_text(encoding="utf-8"))
    finally:
        result_path.unlink(missing_ok=True)
    if completed.returncode != 0 or not result.get("ok"):
        destination.unlink(missing_ok=True)
        raise SystemExit(f"Douyin capture failed: {result.get('error', 'unknown error')}; "
                         f"page_routes={result.get('pageRoutes', [])}; "
                         f"attempts={result.get('attempts', [])}")
    return result["metadata"]


def main() -> None:
    args = parse_args()
    video_id = extract_video_id(args.url)
    canonical_url = f"https://www.douyin.com/video/{video_id}"
    args.output_dir.mkdir(parents=True, exist_ok=True)
    destination = args.output_dir / "source.mp4"
    staging = args.output_dir / ".source-downloading.mp4"
    metadata_destination = args.output_dir / "metadata.json"
    metadata_staging = args.output_dir / ".metadata-downloading.json"
    if destination.exists() and not args.force:
        raise SystemExit(f"Refusing to overwrite {destination}; pass --force")
    staging.unlink(missing_ok=True)
    metadata_staging.unlink(missing_ok=True)
    if args.media_urls_stdin and (args.media_url_file or args.audio_url_file):
        raise SystemExit("--media-urls-stdin cannot be combined with media URL files")
    if args.audio_url_file and not args.media_url_file:
        raise SystemExit("--audio-url-file requires --media-url-file")
    if args.media_urls_stdin:
        captured = json.load(sys.stdin)
        video_url = str(captured.get("video") or "")
        audio_url = str(captured.get("audio") or "")
        if not video_url:
            raise SystemExit("Captured media JSON is missing video URL")
        if audio_url:
            download_and_mux_captured_dash_urls(video_url, audio_url, staging)
        else:
            download_captured_media_url(video_url, staging)
        metadata = {
            "aweme_id": video_id,
            "description": args.title,
            "author": args.author,
            "published_label": args.published_label,
            "source_url": args.url,
        }
    elif args.media_url_file:
        if args.audio_url_file:
            download_and_mux_captured_dash(
                args.media_url_file, args.audio_url_file, staging
            )
        else:
            download_captured_media(args.media_url_file, staging)
        metadata = {
            "aweme_id": video_id,
            "description": args.title,
            "author": args.author,
            "published_label": args.published_label,
            "source_url": args.url,
        }
    else:
        metadata = capture_and_download(
            args.url, video_id, staging, args.runtime_dir, args.profile_dir,
            args.wait_ms, args.title, args.fallback_page_url,
            args.media_stall_timeout_ms, args.cdp_endpoint,
        )
    probe = probe_video(staging)
    duration = float(probe.get("format", {}).get("duration", 0) or 0)
    if duration <= 0:
        raise SystemExit("Downloaded file has no playable duration")
    if args.expected_duration is not None and abs(duration - args.expected_duration) > 2.0:
        raise SystemExit(
            f"Duration mismatch: expected {args.expected_duration:.3f}s, got {duration:.3f}s"
        )
    metadata.update({
        "requested_url": args.url,
        "canonical_url": canonical_url,
        "downloaded_at": datetime.now(timezone.utc).isoformat(),
        "file_name": destination.name,
        "file_size": staging.stat().st_size,
        "sha256": sha256_file(staging),
        "probe": probe,
    })
    metadata_staging.write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    staging.replace(destination)
    metadata_staging.replace(metadata_destination)
    print(json.dumps(metadata, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
