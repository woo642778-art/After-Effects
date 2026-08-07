import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[2]
MODULE_PATH = REPO / "Tools" / "ai" / "audit_models.py"
spec = importlib.util.spec_from_file_location("audit_models", MODULE_PATH)
audit_models = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(audit_models)


class AIModelLockTests(unittest.TestCase):
    def setUp(self):
        self.lock = json.loads((REPO / "AI" / "AI_MODEL_LOCK.json").read_text())

    def test_repository_lock_is_valid(self):
        audit_models.validate_lock(self.lock, REPO)

    def test_model_and_bundle_paths_are_unique(self):
        model_ids = [model["modelID"] for model in self.lock["models"]]
        bundle_paths = [model["bundleRelativePath"] for model in self.lock["models"]]
        self.assertEqual(len(model_ids), len(set(model_ids)))
        self.assertEqual(len(bundle_paths), len(set(bundle_paths)))

    def test_all_network_sources_are_https_and_runtime_is_offline(self):
        for model in self.lock["models"]:
            self.assertTrue(model["upstream"].startswith("https://"))
            download = model["download"]
            if download["kind"] == "files":
                self.assertTrue(all(item["url"].startswith("https://") for item in download["files"]))
            else:
                self.assertTrue(download["url"].startswith("https://"))
        for capability in self.lock["systemCapabilities"]:
            self.assertFalse(capability["serverRequired"])

    def test_invalid_digest_is_rejected(self):
        bad = json.loads(json.dumps(self.lock))
        bad["models"][0]["sourceSHA256"] = "not-a-sha"
        with self.assertRaises(ValueError):
            audit_models.validate_lock(bad, REPO)


if __name__ == "__main__":
    unittest.main()
