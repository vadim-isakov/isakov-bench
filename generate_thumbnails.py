#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = ["playwright"]
# ///
"""
Generate WebM video thumbnails for each result HTML using Playwright's
built-in video recording + ffmpeg for final encoding.
Records at exact thumbnail display size to avoid scaling artifacts.
Uses multiprocessing to capture multiple files in parallel.
"""

import multiprocessing
import os
import subprocess
import sys
import tempfile
from pathlib import Path

THUMB_WIDTH = 500
THUMB_HEIGHT = 400
CAPTURE_DURATION_S = 10
OUTPUT_FPS = 120

BASE_DIR = Path(__file__).parent
RESULTS_DIR = BASE_DIR / "results"
THUMBS_DIR = BASE_DIR / "thumbs"

RECORD_WIDTH = THUMB_WIDTH * 2
RECORD_HEIGHT = THUMB_HEIGHT * 2
VIEWPORT_WIDTH = RECORD_WIDTH
VIEWPORT_HEIGHT = RECORD_HEIGHT

MAX_WORKERS = min(os.cpu_count() or 4, 8)


def capture_one(args):
    html_path, webm_path = args
    html_path, webm_path = Path(html_path), Path(webm_path)

    from playwright.sync_api import sync_playwright

    with tempfile.TemporaryDirectory() as tmp_dir:
        with sync_playwright() as p:
            browser = p.chromium.launch()
            context = browser.new_context(
                viewport={"width": VIEWPORT_WIDTH, "height": VIEWPORT_HEIGHT},
                record_video_dir=tmp_dir,
                record_video_size={"width": RECORD_WIDTH, "height": RECORD_HEIGHT},
            )
            page = context.new_page()
            page.goto(html_path.as_uri())
            page.wait_for_timeout(500 + CAPTURE_DURATION_S * 1000)
            video_path = page.video.path()
            context.close()
            browser.close()

        cmd = [
            "ffmpeg", "-y",
            "-i", str(video_path),
            "-t", str(CAPTURE_DURATION_S),
            "-vf", f"scale={THUMB_WIDTH}:{THUMB_HEIGHT}:flags=lanczos",
            "-r", str(OUTPUT_FPS),
            "-c:v", "libvpx-vp9",
            "-b:v", "0",
            "-crf", "20",
            "-an",
            "-pix_fmt", "yuv420p",
            str(webm_path),
        ]
        subprocess.run(cmd, capture_output=True, check=True)

    size_kb = webm_path.stat().st_size / 1024
    rel = html_path.relative_to(BASE_DIR)
    return f"  {rel} -> {webm_path.relative_to(BASE_DIR)} ({size_kb:.0f} KB)"


def main():
    THUMBS_DIR.mkdir(exist_ok=True)

    html_files = []
    for prompt_dir in sorted(RESULTS_DIR.iterdir()):
        if not prompt_dir.is_dir():
            continue
        thumb_prompt_dir = THUMBS_DIR / prompt_dir.name
        thumb_prompt_dir.mkdir(exist_ok=True)
        for f in sorted(prompt_dir.glob("*.html")):
            webm_path = thumb_prompt_dir / (f.stem + ".webm")
            html_files.append((f, webm_path))

    to_generate = []
    for html_path, webm_path in html_files:
        if webm_path.exists() and webm_path.stat().st_mtime >= html_path.stat().st_mtime:
            print(f"  skip (up to date): {webm_path.relative_to(BASE_DIR)}")
            continue
        to_generate.append((str(html_path), str(webm_path)))

    if not to_generate:
        print("All thumbnails up to date.")
        return

    print(f"Generating {len(to_generate)} thumbnails with {MAX_WORKERS} workers...")

    with multiprocessing.Pool(MAX_WORKERS) as pool:
        for result in pool.imap_unordered(capture_one, to_generate):
            print(result)

    print(f"Done. Generated {len(to_generate)} thumbnails.")


if __name__ == "__main__":
    main()
