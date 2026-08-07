#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import PurePosixPath
import plistlib
import zipfile


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def model_tree_digest(archive: zipfile.ZipFile, root: str) -> tuple[str, int, int]:
    prefix = root.rstrip("/") + "/"
    files = sorted(
        name for name in archive.namelist()
        if name.startswith(prefix) and not name.endswith("/")
    )
    if not files:
        raise AssertionError(f"compiled model is absent or empty: {root}")
    digest = hashlib.sha256()
    total = 0
    for name in files:
        relative = name[len(prefix):].encode("utf-8")
        payload = archive.read(name)
        digest.update(relative)
        digest.update(b"\0")
        digest.update(len(payload).to_bytes(8, "big"))
        digest.update(payload)
        total += len(payload)
    return digest.hexdigest(), total, len(files)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("ipa")
    p.add_argument("--inventory", required=True)
    args = p.parse_args()

    ipa_sha = sha256_file(args.ipa)
    with zipfile.ZipFile(args.ipa) as z:
        app_roots = sorted({
            "/".join(PurePosixPath(name).parts[:2])
            for name in z.namelist()
            if name.startswith("Payload/") and ".app/" in name
        })
        if len(app_roots) != 1:
            raise AssertionError(f"expected one app bundle, found {app_roots}")
        app = app_roots[0]
        info = plistlib.loads(z.read(f"{app}/Info.plist"))
        assert info.get("CFBundleDisplayName") == "After Effects", info
        assert info.get("CFBundleIdentifier") == "com.woo642778.aftereffects", info
        assert info.get("CFBundleShortVersionString") == "7.0.0", info
        assert str(info.get("CFBundleVersion")) == "7", info
        assert info.get("MinimumOSVersion") == "17.0", info
        executable = info.get("CFBundleExecutable")
        assert executable and f"{app}/{executable}" in z.namelist(), "missing executable"
        assert not any(name.startswith(f"{app}/_CodeSignature/") for name in z.namelist()), "unexpected signature"
        assert f"{app}/embedded.mobileprovision" not in z.namelist(), "unexpected provisioning profile"
        assert f"{app}/Assets.car" in z.namelist(), "missing Assets.car"
        assert any(name.endswith("/default.metallib") for name in z.namelist()), "missing Metal library"

        manifest_path = f"{app}/AI_MODEL_MANIFEST.json"
        assert manifest_path in z.namelist(), "missing AI_MODEL_MANIFEST.json"
        manifest = json.loads(z.read(manifest_path))
        models = manifest.get("models", [])
        if len(models) < 3:
            raise AssertionError(f"Phase 7 expects at least 3 audited compiled models; got {len(models)}")

        model_inventory = []
        for model in models:
            relative = model["bundleRelativePath"].strip("/")
            root = f"{app}/{relative}"
            digest, size, file_count = model_tree_digest(z, root)
            if digest.lower() != model["convertedSHA256"].lower():
                raise AssertionError(f"compiled tree SHA mismatch for {model['modelID']}: {digest}")
            if size != model["compiledSizeBytes"]:
                raise AssertionError(f"compiled size mismatch for {model['modelID']}: {size}")
            model_inventory.append({
                "modelID": model["modelID"],
                "bundleRelativePath": relative,
                "treeSHA256": digest,
                "bytes": size,
                "files": file_count,
                "license": model["license"],
                "minimumTier": model["minimumTier"],
            })

        names = z.namelist()
        app_bytes = sum(z.getinfo(name).file_size for name in names if name.startswith(app + "/") and not name.endswith("/"))
        executable_bytes = z.getinfo(f"{app}/{executable}").file_size
        assets_bytes = z.getinfo(f"{app}/Assets.car").file_size
        metallibs = [
            {"path": name[len(app)+1:], "bytes": z.getinfo(name).file_size}
            for name in names if name.startswith(app + "/") and name.endswith(".metallib")
        ]
        frameworks = sorted({
            PurePosixPath(name[len(app)+1:]).parts[1]
            for name in names
            if name.startswith(f"{app}/Frameworks/") and len(PurePosixPath(name[len(app)+1:]).parts) > 1
        })

    inventory = {
        "ipaSHA256": ipa_sha,
        "ipaCompressedBytes": __import__("os").path.getsize(args.ipa),
        "appUncompressedBytes": app_bytes,
        "mainExecutableBytes": executable_bytes,
        "assetsCarBytes": assets_bytes,
        "metallibs": metallibs,
        "frameworks": frameworks,
        "models": model_inventory,
        "identity": {
            "displayName": "After Effects",
            "bundleID": "com.woo642778.aftereffects",
            "version": "7.0.0",
            "build": "7",
            "minimumOS": "17.0",
        },
        "unsigned": True,
    }
    with open(args.inventory, "w", encoding="utf-8") as f:
        json.dump(inventory, f, indent=2, sort_keys=True)
        f.write("\n")
    print(json.dumps(inventory, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
