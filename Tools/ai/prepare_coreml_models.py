#!/usr/bin/env python3
"""Compile pinned Phase 7 model packages and generate the runtime model manifest.

This script performs no downloads. Run fetch_models.py first. It is intended for
macOS/Xcode release builders where `xcrun coremlcompiler` is available.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tempfile
import zipfile


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def tree_digest_and_size(root: Path) -> tuple[str, int]:
    if not root.is_dir():
        raise ValueError(f"compiled model directory does not exist: {root}")
    digest = hashlib.sha256()
    total = 0
    files = sorted(path for path in root.rglob("*") if path.is_file())
    if not files:
        raise ValueError(f"compiled model directory is empty: {root}")
    for path in files:
        relative = path.relative_to(root).as_posix().encode("utf-8")
        payload = path.read_bytes()
        digest.update(relative)
        digest.update(b"\0")
        digest.update(len(payload).to_bytes(8, "big"))
        digest.update(payload)
        total += len(payload)
    return digest.hexdigest(), total


def safe_extract(zip_path: Path, destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path) as archive:
        for info in archive.infolist():
            pure = PurePosixPath(info.filename)
            if pure.is_absolute() or ".." in pure.parts:
                raise ValueError(f"unsafe archive member: {info.filename}")
            target = destination.joinpath(*pure.parts)
            resolved = target.resolve()
            if destination.resolve() not in resolved.parents and resolved != destination.resolve():
                raise ValueError(f"archive member escapes destination: {info.filename}")
        archive.extractall(destination)


def find_single_package(root: Path) -> Path:
    packages = sorted(path for path in root.rglob("*.mlpackage") if path.is_dir())
    if len(packages) != 1:
        raise ValueError(f"expected one .mlpackage below {root}, found {len(packages)}")
    return packages[0]


def compile_package(package: Path, output_dir: Path) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["xcrun", "coremlcompiler", "compile", str(package), str(output_dir)],
        check=True,
    )
    compiled = output_dir / f"{package.stem}.mlmodelc"
    if not compiled.is_dir():
        candidates = sorted(output_dir.glob("*.mlmodelc"))
        if len(candidates) != 1:
            raise ValueError(f"coremlcompiler produced no unique compiled model for {package}")
        compiled = candidates[0]
    return compiled


def package_for_model(model: dict, source_root: Path, temp_root: Path) -> Path:
    download = model["download"]
    if download["kind"] == "files":
        package = source_root / model["sourcePath"]
        if not package.is_dir():
            raise ValueError(f"missing source package for {model['modelID']}: {package}")
        return package
    if download["kind"] == "archive":
        archive = source_root / model["sourcePath"]
        if not archive.is_file():
            raise ValueError(f"missing source archive for {model['modelID']}: {archive}")
        extraction = temp_root / model["modelID"]
        safe_extract(archive, extraction)
        return find_single_package(extraction)
    raise ValueError(f"unsupported download kind for {model['modelID']}")


def copy_notices(lock: dict, repository_root: Path, output_root: Path) -> None:
    notices = output_root / "AIModelNotices"
    if notices.exists():
        shutil.rmtree(notices)
    notices.mkdir(parents=True)
    copied: set[Path] = set()
    for model in lock["models"]:
        path = repository_root / model["noticePath"]
        if not path.is_file():
            raise ValueError(f"missing notice for {model['modelID']}: {path}")
        if path not in copied:
            shutil.copy2(path, notices / path.name)
            copied.add(path)
    apache = repository_root / "AI/LICENSES/APACHE-2.0.txt"
    if apache.is_file():
        shutil.copy2(apache, notices / apache.name)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lock", default="AI/AI_MODEL_LOCK.json")
    parser.add_argument("--source-root", default=".build/ai-source")
    parser.add_argument("--output-root", default="App/GeneratedAIResources")
    parser.add_argument("--repository-root", default=".")
    args = parser.parse_args()

    repository_root = Path(args.repository_root)
    lock = json.loads(Path(args.lock).read_text(encoding="utf-8"))
    source_root = Path(args.source_root)
    output_root = Path(args.output_root)
    models_root = output_root / "AIModels"
    models_root.mkdir(parents=True, exist_ok=True)

    # Remove only generated compiled model directories. Keep repository placeholders.
    for path in models_root.glob("*.mlmodelc"):
        if path.is_dir():
            shutil.rmtree(path)

    runtime_models: list[dict] = []
    with tempfile.TemporaryDirectory(prefix="vertex-ai-prepare-") as temp_name:
        temp_root = Path(temp_name)
        for model in lock["models"]:
            package = package_for_model(model, source_root, temp_root)
            with tempfile.TemporaryDirectory(prefix="vertex-coreml-compile-") as compile_name:
                compiled = compile_package(package, Path(compile_name))
                expected_name = PurePosixPath(model["bundleRelativePath"]).name
                destination = models_root / expected_name
                if destination.exists():
                    shutil.rmtree(destination)
                shutil.copytree(compiled, destination, symlinks=False)
            digest, size = tree_digest_and_size(destination)
            runtime_models.append({
                "modelID": model["modelID"],
                "task": model["task"],
                "upstream": model["upstream"],
                "upstreamVersion": model["upstreamVersion"],
                "license": model["license"],
                "sourceSHA256": model["sourceSHA256"],
                "convertedSHA256": digest,
                "precision": model["precision"],
                "compiledSizeBytes": size,
                "minimumTier": model["minimumTier"],
                "bundleRelativePath": model["bundleRelativePath"],
            })
            print(f"compiled {model['modelID']} -> {destination} ({size} bytes, {digest})")

    copy_notices(lock, repository_root, output_root)
    manifest = {"formatVersion": 1, "models": runtime_models}
    output_root.mkdir(parents=True, exist_ok=True)
    manifest_path = output_root / "AI_MODEL_MANIFEST.json"
    manifest_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
