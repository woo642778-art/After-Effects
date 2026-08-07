#!/usr/bin/env python3
"""Validate AI model lock metadata and downloaded source integrity."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re

SHA256 = re.compile(r"^[0-9a-f]{64}$")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def ensure_relative(value: str, label: str) -> None:
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or not path.parts:
        raise ValueError(f"{label} must be a safe relative path: {value}")


def validate_lock(lock: dict, repository_root: Path) -> None:
    if lock.get("formatVersion") != 1:
        raise ValueError("formatVersion must be 1")
    model_ids: set[str] = set()
    bundle_paths: set[str] = set()
    for model in lock.get("models", []):
        model_id = model.get("modelID", "")
        if not model_id or model_id in model_ids:
            raise ValueError(f"modelID must be nonempty and unique: {model_id}")
        model_ids.add(model_id)

        upstream = model.get("upstream", "")
        if not upstream.startswith("https://"):
            raise ValueError(f"upstream must be HTTPS for {model_id}")
        if not model.get("license"):
            raise ValueError(f"license is required for {model_id}")
        if not SHA256.fullmatch(model.get("sourceSHA256", "")):
            raise ValueError(f"sourceSHA256 must be 64 lowercase hex characters for {model_id}")

        bundle_path = model.get("bundleRelativePath", "")
        ensure_relative(bundle_path, f"bundleRelativePath for {model_id}")
        if bundle_path in bundle_paths:
            raise ValueError(f"duplicate bundleRelativePath: {bundle_path}")
        bundle_paths.add(bundle_path)

        notice = model.get("noticePath", "")
        ensure_relative(notice, f"noticePath for {model_id}")
        if not (repository_root / notice).is_file():
            raise ValueError(f"license notice is missing for {model_id}: {notice}")

        download = model.get("download", {})
        if download.get("kind") == "files":
            for item in download.get("files", []):
                if not item.get("url", "").startswith("https://"):
                    raise ValueError(f"file URL must be HTTPS for {model_id}")
                ensure_relative(item.get("relativePath", ""), f"download path for {model_id}")
                if not SHA256.fullmatch(item.get("sha256", "")):
                    raise ValueError(f"download SHA-256 is invalid for {model_id}")
        elif download.get("kind") == "archive":
            if not download.get("url", "").startswith("https://"):
                raise ValueError(f"archive URL must be HTTPS for {model_id}")
            if not SHA256.fullmatch(download.get("sha256", "")):
                raise ValueError(f"archive SHA-256 is invalid for {model_id}")
            ensure_relative(model.get("sourcePath", ""), f"sourcePath for {model_id}")
        else:
            raise ValueError(f"unsupported download kind for {model_id}")


def audit_downloaded_sources(lock: dict, source_root: Path) -> None:
    for model in lock.get("models", []):
        model_id = model["modelID"]
        download = model["download"]
        if download["kind"] == "files":
            for item in download["files"]:
                path = source_root / item["relativePath"]
                if not path.is_file():
                    raise ValueError(f"missing source file for {model_id}: {path}")
                actual = sha256_file(path)
                if actual != item["sha256"]:
                    raise ValueError(f"source checksum mismatch for {model_id}: {path}")
        else:
            path = source_root / model["sourcePath"]
            if not path.is_file():
                raise ValueError(f"missing source archive for {model_id}: {path}")
            actual = sha256_file(path)
            if actual != download["sha256"]:
                raise ValueError(f"archive checksum mismatch for {model_id}: {path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lock", default="AI/AI_MODEL_LOCK.json")
    parser.add_argument("--repository-root", default=".")
    parser.add_argument("--source-root")
    args = parser.parse_args()

    lock_path = Path(args.lock)
    repository_root = Path(args.repository_root)
    lock = json.loads(lock_path.read_text(encoding="utf-8"))
    validate_lock(lock, repository_root)
    if args.source_root:
        audit_downloaded_sources(lock, Path(args.source_root))
    print(f"AI model lock audit passed for {len(lock.get('models', []))} bundled models")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
