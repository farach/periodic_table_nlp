from __future__ import annotations

import csv
import hashlib
import os
from pathlib import Path

from huggingface_hub import snapshot_download


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = PROJECT_ROOT / "data" / "nlg-models.csv"
MODEL_ROOT = PROJECT_ROOT / "data-raw" / ".cache" / "nlg-models"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def verify_model(row: dict[str, str], model_path: Path) -> None:
    required_files = row["required_files"].split(";")
    missing = [name for name in required_files if not (model_path / name).is_file()]
    if missing:
        raise RuntimeError(
            f"{row['model_id']} is missing required files: {', '.join(missing)}"
        )

    weight_path = model_path / row["weight_file"]
    actual_bytes = weight_path.stat().st_size
    expected_bytes = int(row["weight_bytes"])
    if actual_bytes != expected_bytes:
        raise RuntimeError(
            f"{weight_path} has {actual_bytes} bytes; expected {expected_bytes}"
        )

    actual_hash = sha256(weight_path)
    if actual_hash != row["weight_sha256"]:
        raise RuntimeError(
            f"{weight_path} has SHA-256 {actual_hash}; "
            f"expected {row['weight_sha256']}"
        )


def main() -> None:
    os.environ.setdefault("HF_HUB_DISABLE_TELEMETRY", "1")
    os.environ.setdefault("HF_HUB_DISABLE_XET", "1")
    MODEL_ROOT.mkdir(parents=True, exist_ok=True)

    with MANIFEST_PATH.open(encoding="utf-8", newline="") as stream:
        models = list(csv.DictReader(stream))

    for row in models:
        model_path = MODEL_ROOT / row["local_directory"]
        try:
            verify_model(row, model_path)
            action = "verified"
        except (FileNotFoundError, RuntimeError):
            snapshot_download(
                repo_id=row["model_id"],
                revision=row["revision"],
                allow_patterns=row["required_files"].split(";"),
                local_dir=model_path,
            )
            verify_model(row, model_path)
            action = "downloaded and verified"

        print(
            f"{action}: {row['model_id']}@{row['revision']} "
            f"({int(row['weight_bytes']) / 1024**2:.1f} MiB weights)"
        )


if __name__ == "__main__":
    main()
