#!/usr/bin/env python3
"""Fetch only Phase 7 AI assets pinned by AI_MODEL_LOCK.json.

The downloader is fail-closed: bytes are written to a temporary file, SHA-256 is
verified, and only then is the destination atomically replaced.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import tempfile
import urllib.request


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_relative(value: str) -> Path:
    posix = PurePosixPath(value)
    if posix.is_absolute() or ".." in posix.parts or not posix.parts:
        raise ValueError(f"unsafe relative path: {value}")
    return Path(*posix.parts)


def download_verified(url: str, destination: Path, expected_sha256: str) -> None:
    if destination.is_file() and sha256_file(destination) == expected_sha256:
        print(f"verified cached {destination}")
        return

    destination.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "After-Effects-VertexAI-model-fetch/7.0"},
    )
    fd, temporary_name = tempfile.mkstemp(prefix=".download-", dir=destination.parent)
    os.close(fd)
    temporary = Path(temporary_name)
    try:
        with urllib.request.urlopen(request, timeout=120) as response, temporary.open("wb") as output:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                output.write(chunk)
        actual = sha256_file(temporary)
        if actual != expected_sha256:
            raise RuntimeError(
                f"SHA-256 mismatch for {url}: expected {expected_sha256}, got {actual}"
            )
        os.replace(temporary, destination)
        print(f"fetched {destination} ({actual})")
    finally:
        temporary.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lock", default="AI/AI_MODEL_LOCK.json")
    parser.add_argument(
        "--output",
        "--destination",
        dest="output",
        default=".build/ai-source",
        help="Directory used for verified pinned model sources.",
    )
    args = parser.parse_args()

    lock_path = Path(args.lock)
    output_root = Path(args.output)
    lock = json.loads(lock_path.read_text(encoding="utf-8"))
    if lock.get("formatVersion") != 1:
        raise SystemExit("unsupported AI model lock format")

    for model in lock.get("models", []):
        download = model["download"]
        kind = download["kind"]
        if kind == "files":
            for item in download["files"]:
                destination = output_root / safe_relative(item["relativePath"])
                download_verified(item["url"], destination, item["sha256"])
        elif kind == "archive":
            destination = output_root / safe_relative(model["sourcePath"])
            download_verified(download["url"], destination, download["sha256"])
        else:
            raise SystemExit(f"unsupported download kind for {model['modelID']}: {kind}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
