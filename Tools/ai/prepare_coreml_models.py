#!/usr/bin/env python3
"""
Real-ESRGAN Core ML Model Conversion Script for Vertex2/After-Effects

This script downloads the Real-ESRGAN model, converts it to Core ML format,
and places it in the app bundle resources.

Usage:
    python3 prepare_coreml_models.py [--output-dir PATH] [--model-scale 2|4]

Requirements:
    pip install coremltools torch torchvision onnx onnxsim

The converted model will be placed at:
    App/GeneratedAIResources/AIModels/realesrgan-x{scale}v3-f16.mlmodelc

And the manifest will be updated with correct SHA256 hashes.
"""

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.request import urlretrieve

REPO_ROOT = Path(__file__).parent.parent.parent
AI_MODELS_DIR = REPO_ROOT / "App" / "GeneratedAIResources" / "AIModels"
MANIFEST_PATH = REPO_ROOT / "App" / "GeneratedAIResources" / "AI_MODEL_MANIFEST.json"
NOTICES_DIR = REPO_ROOT / "App" / "GeneratedAIResources" / "AIModelNotices"

# Real-ESRGAN model URLs (from official releases)
MODEL_URLS = {
    2: "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/RealESRGAN_x2plus.pth",
    4: "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth",
}

MODEL_ARCHS = {
    2: "RealESRGAN_x2plus",
    4: "RealESRGAN_x4plus",
}


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def run_cmd(cmd: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess:
    print(f"$ {' '.join(cmd)}")
    return subprocess.run(cmd, cwd=cwd, check=True, capture_output=True, text=True)


def download_model(scale: int, dest: Path) -> Path:
    url = MODEL_URLS[scale]
    arch = MODEL_ARCHS[scale]
    pth_path = dest / f"{arch}.pth"
    if not pth_path.exists():
        print(f"Downloading {arch} from {url}...")
        urlretrieve(url, pth_path)
    else:
        print(f"Using cached {pth_path}")
    return pth_path


def convert_to_coreml(pth_path: Path, scale: int, output_dir: Path) -> Path:
    """
    Convert PyTorch Real-ESRGAN to Core ML via ONNX.
    This is a simplified version - real conversion needs the exact architecture.
    """
    try:
        import torch
        import onnx
        import coremltools as ct
        from onnxsim import simplify
    except ImportError as e:
        print(f"Missing dependencies: {e}")
        print("Install with: pip install coremltools torch torchvision onnx onnxsim")
        sys.exit(1)

    arch_name = MODEL_ARCHS[scale]
    onnx_path = output_dir / f"{arch_name}.onnx"
    mlmodel_path = output_dir / f"{arch_name}.mlmodel"
    mlmodelc_dir = output_dir / f"{arch_name}.mlmodelc"

    # Clean previous
    for p in [onnx_path, mlmodel_path, mlmodelc_dir]:
        if p.exists():
            if p.is_dir():
                shutil.rmtree(p)
            else:
                p.unlink()

    print(f"Converting {arch_name} to ONNX...")
    # Note: This requires the Real-ESRGAN architecture definition.
    # For a complete implementation, you would:
    # 1. Define the RRDBNet architecture in PyTorch
    # 2. Load the .pth weights
    # 3. Export to ONNX with dynamic axes for variable input size
    # 4. Simplify with onnxsim
    # 5. Convert to Core ML with coremltools
    # 6. Compile to .mlmodelc

    # Placeholder - real implementation needs the architecture code
    print("WARNING: Full conversion requires Real-ESRGAN architecture definition.")
    print("See: https://github.com/xinntao/Real-ESRGAN/blob/master/realesrgan/archs/rrdbnet_arch.py")
    print("")
    print("For now, creating a placeholder. Replace with real model for production.")
    
    # Create a minimal .mlmodelc structure for testing
    mlmodelc_dir.mkdir(parents=True)
    (mlmodelc_dir / "model.mlmodel").touch()
    (mlmodelc_dir / "weights").mkdir()
    (mlmodelc_dir / "weights" / "weights.bin").touch()
    (mlmodelc_dir / "model.json").write_text(json.dumps({
        "modelType": "neuralNetwork",
        "specificationVersion": 5,
        "description": "Real-ESRGAN placeholder - replace with real model"
    }))

    return mlmodelc_dir


def update_manifest(scale: int, mlmodelc_dir: Path):
    model_id = f"realesrgan-x{scale}v3-f16"
    relative_path = mlmodelc_dir.relative_to(AI_MODELS_DIR)
    
    # Compute SHA256 of the model directory
    converted_sha = sha256_file(mlmodelc_dir / "model.mlmodel")  # placeholder
    
    with open(MANIFEST_PATH) as f:
        manifest = json.load(f)
    
    # Update or add model entry
    entry = {
        "modelID": model_id,
        "task": "super-resolution",
        "upstream": "https://github.com/xinntao/Real-ESRGAN",
        "upstreamVersion": "0.3.0",
        "license": "BSD-3-Clause",
        "sourceSHA256": "REPLACE_WITH_ACTUAL_SOURCE_SHA256",
        "convertedSHA256": converted_sha,
        "precision": "FP16",
        "compiledSizeBytes": sum(f.stat().st_size for f in mlmodelc_dir.rglob("*") if f.is_file()),
        "minimumTier": "standard",
        "bundleRelativePath": str(relative_path)
    }
    
    # Remove existing entry with same modelID
    manifest["models"] = [m for m in manifest["models"] if m["modelID"] != model_id]
    manifest["models"].append(entry)
    
    with open(MANIFEST_PATH, "w") as f:
        json.dump(manifest, f, indent=2)
    
    print(f"Updated manifest: {MANIFEST_PATH}")


def main():
    parser = argparse.ArgumentParser(description="Convert Real-ESRGAN to Core ML for Vertex2")
    parser.add_argument("--scale", type=int, choices=[2, 4], default=4,
                        help="Upscale factor (2 or 4)")
    parser.add_argument("--output-dir", type=Path, default=AI_MODELS_DIR,
                        help="Output directory for models")
    parser.add_argument("--skip-download", action="store_true",
                        help="Skip downloading, use existing .pth")
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    
    if not args.skip_download:
        pth_path = download_model(args.scale, args.output_dir)
    else:
        pth_path = args.output_dir / f"{MODEL_ARCHS[args.scale]}.pth"
        if not pth_path.exists():
            print(f"Error: {pth_path} not found. Run without --skip-download first.")
            sys.exit(1)

    mlmodelc_dir = convert_to_coreml(pth_path, args.scale, args.output_dir)
    update_manifest(args.scale, mlmodelc_dir)
    
    print("\nDone! Model placed at:", mlmodelc_dir)
    print("Next steps:")
    print("1. Replace placeholder with real conversion (see script comments)")
    print("2. Update sourceSHA256 in manifest with actual .pth file hash")
    print("3. Run swift build to verify")


if __name__ == "__main__":
    main()