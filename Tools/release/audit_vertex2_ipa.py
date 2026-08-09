#!/usr/bin/env python3
import argparse
import hashlib
import json
import plistlib
import re
import struct
import tempfile
import zipfile
from pathlib import Path, PurePosixPath

EXPECTED = {
    "CFBundleDisplayName": "Vertex2",
    "CFBundleIdentifier": "com.woo642778.aftereffects",
    "CFBundleShortVersionString": "10.0.0",
    "CFBundleVersion": "10",
    "MinimumOSVersion": "17.0",
}

EXPECTED_MODELS = {
    "depth-anything-v2-small-f16": "AIModels/DepthAnythingV2SmallF16.mlmodelc",
    "realesrgan-x4v3-f16": "AIModels/RealESRGAN-x4v3.mlmodelc",
    "realesrgan-x4v3-denoise-f16": "AIModels/RealESRGAN-x4v3-denoise.mlmodelc",
}

EXPECTED_NOTICES = {
    "DEPTH_ANYTHING_V2_NOTICE.md",
    "REALESRGAN_NOTICE.md",
    "APACHE-2.0.txt",
}

SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")


def fail(message: str) -> None:
    raise SystemExit(f"AUDIT FAILED: {message}")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def tree_digest_and_size(root: Path) -> tuple[str, int, int]:
    if not root.is_dir():
        fail(f"Compiled model directory is missing: {root}")
    files = sorted(path for path in root.rglob("*") if path.is_file())
    if not files:
        fail(f"Compiled model directory is empty: {root}")
    digest = hashlib.sha256()
    total = 0
    for path in files:
        relative = path.relative_to(root).as_posix().encode("utf-8")
        payload = path.read_bytes()
        digest.update(relative)
        digest.update(b"\0")
        digest.update(len(payload).to_bytes(8, "big"))
        digest.update(payload)
        total += len(payload)
    return digest.hexdigest(), total, len(files)


def safe_bundle_path(value: str) -> Path:
    pure = PurePosixPath(value)
    if pure.is_absolute() or ".." in pure.parts or not pure.parts:
        fail(f"Unsafe AI model bundle path: {value!r}")
    return Path(*pure.parts)


def is_arm64_macho(path: Path) -> bool:
    data = path.read_bytes()[:8]
    if len(data) < 8:
        return False
    magic, cpu = struct.unpack("<II", data)
    return magic == 0xFEEDFACF and cpu == 0x0100000C


def audit_ai_resources(app: Path) -> dict:
    manifest_path = app / "AI_MODEL_MANIFEST.json"
    if not manifest_path.is_file():
        fail("AI_MODEL_MANIFEST.json is missing from the app bundle")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"AI model manifest is unreadable: {error}")
    if manifest.get("formatVersion") != 1:
        fail(f"AI model manifest formatVersion must be 1, found {manifest.get('formatVersion')!r}")

    models = manifest.get("models")
    if not isinstance(models, list):
        fail("AI model manifest models must be an array")
    model_ids = [model.get("modelID") for model in models if isinstance(model, dict)]
    if len(models) != len(EXPECTED_MODELS) or set(model_ids) != set(EXPECTED_MODELS):
        fail(f"Expected exactly the three pinned AI models, found {model_ids!r}")

    compiled_total = 0
    compiled_files = 0
    verified_models = []
    for model in models:
        model_id = model["modelID"]
        expected_relative = EXPECTED_MODELS[model_id]
        actual_relative = model.get("bundleRelativePath")
        if actual_relative != expected_relative:
            fail(
                f"{model_id} bundleRelativePath: expected {expected_relative!r}, "
                f"found {actual_relative!r}"
            )
        if not model.get("license"):
            fail(f"{model_id} is missing license metadata")
        source_digest = model.get("sourceSHA256", "")
        converted_digest = model.get("convertedSHA256", "")
        if not SHA256_PATTERN.fullmatch(source_digest):
            fail(f"{model_id} has invalid sourceSHA256")
        if not SHA256_PATTERN.fullmatch(converted_digest):
            fail(f"{model_id} has invalid convertedSHA256")

        compiled_root = app / safe_bundle_path(expected_relative)
        digest, size, file_count = tree_digest_and_size(compiled_root)
        if digest != converted_digest:
            fail(
                f"{model_id} compiled digest mismatch: expected {converted_digest}, got {digest}"
            )
        declared_size = model.get("compiledSizeBytes")
        if not isinstance(declared_size, int) or declared_size <= 0:
            fail(f"{model_id} has invalid compiledSizeBytes: {declared_size!r}")
        if size != declared_size:
            fail(
                f"{model_id} compiled size mismatch: expected {declared_size}, got {size}"
            )
        compiled_total += size
        compiled_files += file_count
        verified_models.append(
            {
                "model_id": model_id,
                "bundle_path": expected_relative,
                "compiled_sha256": digest,
                "compiled_size_bytes": size,
                "compiled_file_count": file_count,
            }
        )

    notices_root = app / "AIModelNotices"
    missing_notices = sorted(
        notice for notice in EXPECTED_NOTICES
        if not (notices_root / notice).is_file() or (notices_root / notice).stat().st_size == 0
    )
    if missing_notices:
        fail(f"Required AI model license notices are missing or empty: {missing_notices!r}")

    return {
        "ai_manifest_count": 1,
        "ai_model_resource_count": len(verified_models),
        "ai_model_compiled_bytes": compiled_total,
        "ai_model_compiled_file_count": compiled_files,
        "ai_models": verified_models,
        "ai_notice_count": len(EXPECTED_NOTICES),
    }


def audit(ipa: Path) -> dict:
    if not ipa.is_file():
        fail(f"IPA does not exist: {ipa}")
    with tempfile.TemporaryDirectory(prefix="vertex2-ipa-audit-") as temp:
        root = Path(temp)
        with zipfile.ZipFile(ipa) as archive:
            archive.extractall(root)
        apps = list((root / "Payload").glob("*.app"))
        if len(apps) != 1:
            fail(f"Expected exactly one app in Payload, found {len(apps)}")
        app = apps[0]
        plist_path = app / "Info.plist"
        if not plist_path.is_file():
            fail("Info.plist missing")
        with plist_path.open("rb") as handle:
            info = plistlib.load(handle)

        for key, expected in EXPECTED.items():
            actual = str(info.get(key, ""))
            if actual != expected:
                fail(f"{key}: expected {expected!r}, found {actual!r}")

        families = info.get("UIDeviceFamily")
        if families != [2]:
            fail(f"UIDeviceFamily must be [2], found {families!r}")

        orientations = info.get("UISupportedInterfaceOrientations~ipad") or info.get("UISupportedInterfaceOrientations") or []
        expected_orientations = {"UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"}
        if set(orientations) != expected_orientations:
            fail(f"iPad orientations must be landscape only, found {orientations!r}")

        executable_name = info.get("CFBundleExecutable")
        executable = app / str(executable_name)
        if not executable.is_file():
            fail(f"Executable missing: {executable_name}")
        if not is_arm64_macho(executable):
            fail("Executable is not a thin arm64 Mach-O")

        if (app / "_CodeSignature").exists():
            fail("Unsigned artifact unexpectedly contains _CodeSignature")
        if (app / "embedded.mobileprovision").exists():
            fail("Unsigned artifact unexpectedly contains embedded.mobileprovision")

        metal_files = [path for path in app.rglob("*") if path.is_file() and path.suffix.lower() == ".metallib"]
        if not metal_files:
            fail("No Metal library was found in the app bundle")

        ai = audit_ai_resources(app)
        return {
            "artifact": ipa.name,
            "sha256": sha256(ipa),
            "size_bytes": ipa.stat().st_size,
            "app": app.name,
            "bundle_identifier": info["CFBundleIdentifier"],
            "version": info["CFBundleShortVersionString"],
            "build": info["CFBundleVersion"],
            "minimum_os": info["MinimumOSVersion"],
            "device_family": families,
            "orientations": orientations,
            "executable": executable_name,
            "arm64": True,
            "unsigned": True,
            "metal_library_count": len(metal_files),
            **ai,
        }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("ipa", type=Path)
    parser.add_argument("--json", type=Path)
    args = parser.parse_args()
    result = audit(args.ipa)
    payload = json.dumps(result, indent=2, sort_keys=True)
    print(payload)
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(payload + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
