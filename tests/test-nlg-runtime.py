from __future__ import annotations

import importlib.util
import shutil
from pathlib import Path
from tempfile import TemporaryDirectory


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = PROJECT_ROOT / "scripts" / "setup-nlg-models.py"

spec = importlib.util.spec_from_file_location("setup_nlg_models", SCRIPT_PATH)
setup_nlg_models = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(setup_nlg_models)

models, files = setup_nlg_models.load_manifests()
assert len(models) == 3
assert len(files) == 23
assert all(len(row["sha256"]) == 64 for row in files)
assert all(int(row["bytes"]) > 0 for row in files)

for model in models:
    model_files = [
        row for row in files if row["model_key"] == model["model_key"]
    ]
    model_path = setup_nlg_models.MODEL_ROOT / model["local_directory"]
    setup_nlg_models.verify_model(model, model_files, model_path)

model = models[0]
small_file = next(
    row for row in files
    if row["model_key"] == model["model_key"]
    and row["file_path"] == "config.json"
)
source = (
    setup_nlg_models.MODEL_ROOT
    / model["local_directory"]
    / small_file["file_path"]
)

with TemporaryDirectory() as temp:
    model_root = Path(temp)
    fixture = model_root / model["local_directory"]
    fixture.mkdir(parents=True)
    target = fixture / small_file["file_path"]
    shutil.copy2(source, target)
    setup_nlg_models.verify_model(model, [small_file], fixture)

    target.unlink()
    try:
        setup_nlg_models.verify_model(model, [small_file], fixture)
    except RuntimeError as error:
        assert str(target) in str(error)
        assert "missing" in str(error)
    else:
        raise AssertionError("Missing runtime file was accepted")

    shutil.copy2(source, target)
    target.write_bytes(target.read_bytes() + b"x")
    try:
        setup_nlg_models.verify_model(model, [small_file], fixture)
    except RuntimeError as error:
        assert str(target) in str(error)
        assert "bytes" in str(error)
    else:
        raise AssertionError("Changed byte count was accepted")

    shutil.copy2(source, target)
    content = bytearray(target.read_bytes())
    content[0] ^= 1
    target.write_bytes(content)
    def unexpected_download(**kwargs):
        raise AssertionError(f"Corrupt cache triggered a download: {kwargs}")

    try:
        setup_nlg_models.prepare_model(
            model,
            [small_file],
            model_root=model_root,
            download_snapshot=unexpected_download,
        )
    except RuntimeError as error:
        assert str(target) in str(error)
        assert "SHA-256" in str(error)
    else:
        raise AssertionError("Same-size nonweight tampering was accepted")

print("NLG file-manifest and fail-closed integrity tests passed")
