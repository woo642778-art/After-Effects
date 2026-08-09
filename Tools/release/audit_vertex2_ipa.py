#!/usr/bin/env python3
import argparse
import hashlib
import json
import plistlib
import shutil
import struct
import tempfile
import zipfile
from pathlib import Path

EXPECTED = {
    "CFBundleDisplayName": "Vertex2",
    "CFBundleIdentifier": "com.woo642778.aftereffects",
    "CFBundleShortVersionString": "10.0.0",
    "CFBundleVersion": "10",
    "MinimumOSVersion": "17.0",
}


def fail(message: str) -> None:
    raise SystemExit(f"AUDIT FAILED: {message}")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def is_arm64_macho(path: Path) -> bool:
    data = path.read_bytes()[:8]
    if len(data) < 8:
        return False
    magic, cpu = struct.unpack("<II", data)
    return magic == 0xFEEDFACF and cpu == 0x0100000C


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

        resources = [path for path in app.rglob("*") if path.is_file()]
        manifest_matches = [path for path in resources if path.name == "AI_MODEL_MANIFEST.json"]
        if not manifest_matches:
            fail("AI_MODEL_MANIFEST.json is missing from the app bundle")
        model_files = [path for path in resources if path.suffix.lower() in {".mlmodelc", ".mlpackage", ".mlmodel"} or "AIModels" in path.parts]
        if not model_files:
            fail("No packaged AI model resources were found")
        metal_files = [path for path in resources if path.suffix.lower() == ".metallib"]
        if not metal_files:
            fail("No Metal library was found in the app bundle")

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
            "ai_manifest_count": len(manifest_matches),
            "ai_model_resource_count": len(model_files),
            "metal_library_count": len(metal_files),
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
