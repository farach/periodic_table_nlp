from __future__ import annotations

import csv
import hashlib
import os
from pathlib import Path

from huggingface_hub import snapshot_download


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = PROJECT_ROOT / "data" / "nlg-models.csv"
FILE_MANIFEST_PATH = PROJECT_ROOT / "data" / "nlg-model-files.csv"
MODEL_ROOT = PROJECT_ROOT / "data-raw" / ".cache" / "nlg-models"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as stream:
        return list(csv.DictReader(stream))


def load_manifests() -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    models = read_csv(MANIFEST_PATH)
    files = read_csv(FILE_MANIFEST_PATH)
    model_keys = [row["model_key"] for row in models]

    if len(model_keys) != len(set(model_keys)):
        raise RuntimeError(f"{MANIFEST_PATH} contains duplicate model keys")

    model_by_key = {row["model_key"]: row for row in models}
    seen_files: set[tuple[str, str]] = set()
    for file_row in files:
        model_key = file_row["model_key"]
        if model_key not in model_by_key:
            raise RuntimeError(
                f"{FILE_MANIFEST_PATH} references unknown model key {model_key}"
            )

        model_row = model_by_key[model_key]
        for field in ("model_id", "revision", "local_directory"):
            if file_row[field] != model_row[field]:
                raise RuntimeError(
                    f"{FILE_MANIFEST_PATH} has {field}={file_row[field]!r} "
                    f"for {model_key}; expected {model_row[field]!r}"
                )

        relative_path = Path(file_row["file_path"])
        if relative_path.is_absolute() or ".." in relative_path.parts:
            raise RuntimeError(
                f"{FILE_MANIFEST_PATH} contains unsafe path "
                f"{file_row['file_path']!r}"
            )

        file_key = (model_key, file_row["file_path"])
        if file_key in seen_files:
            raise RuntimeError(
                f"{FILE_MANIFEST_PATH} contains duplicate file {file_key}"
            )
        seen_files.add(file_key)

    missing_file_sets = sorted(set(model_keys) - {row["model_key"] for row in files})
    if missing_file_sets:
        raise RuntimeError(
            f"{FILE_MANIFEST_PATH} has no runtime files for "
            f"{', '.join(missing_file_sets)}"
        )

    return models, files


def verify_model(
    row: dict[str, str],
    file_rows: list[dict[str, str]],
    model_path: Path,
) -> None:
    if not model_path.is_dir():
        raise RuntimeError(f"{model_path}: pinned snapshot directory is missing")

    for file_row in file_rows:
        file_path = model_path / file_row["file_path"]
        expected_bytes = int(file_row["bytes"])
        expected_hash = file_row["sha256"]

        if not file_path.is_file():
            raise RuntimeError(
                f"{file_path}: missing; expected {expected_bytes} bytes "
                f"and SHA-256 {expected_hash}"
            )

        actual_bytes = file_path.stat().st_size
        if actual_bytes != expected_bytes:
            raise RuntimeError(
                f"{file_path}: found {actual_bytes} bytes; "
                f"expected {expected_bytes}"
            )

        actual_hash = sha256(file_path)
        if actual_hash != expected_hash:
            raise RuntimeError(
                f"{file_path}: found SHA-256 {actual_hash}; "
                f"expected {expected_hash}"
            )


def prepare_model(
    row: dict[str, str],
    file_rows: list[dict[str, str]],
    model_root: Path = MODEL_ROOT,
    download_snapshot=snapshot_download,
) -> str:
    model_path = model_root / row["local_directory"]
    if model_path.exists():
        verify_model(row, file_rows, model_path)
        return "verified"

    download_snapshot(
        repo_id=row["model_id"],
        revision=row["revision"],
        allow_patterns=[file_row["file_path"] for file_row in file_rows],
        local_dir=model_path,
    )
    verify_model(row, file_rows, model_path)
    return "downloaded and verified"


def main() -> None:
    os.environ.setdefault("HF_HUB_DISABLE_TELEMETRY", "1")
    os.environ.setdefault("HF_HUB_DISABLE_XET", "1")
    MODEL_ROOT.mkdir(parents=True, exist_ok=True)

    models, files = load_manifests()

    for row in models:
        file_rows = [
            file_row for file_row in files
            if file_row["model_key"] == row["model_key"]
        ]
        action = prepare_model(row, file_rows)
        total_bytes = sum(int(file_row["bytes"]) for file_row in file_rows)

        print(
            f"{action}: {row['model_id']}@{row['revision']} "
            f"({len(file_rows)} runtime files, {total_bytes / 1024**2:.1f} MiB)"
        )


if __name__ == "__main__":
    main()
