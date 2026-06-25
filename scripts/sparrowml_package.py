#!/usr/bin/env python3
"""Import, validate, and summarize the frozen SparrowML deployment package."""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "third_party" / "sparrowml"
DEFAULT_SRC = ROOT.parent / "sparrow-ml" / "artifacts" / "phase8_wisdm" / "phase8c"
PACKAGE_SRC = "rtl_package"
TEXT_FILES = [
    "rtl_package/README.md",
    "rtl_package/expected_output.json",
    "rtl_package/export_report.json",
    "rtl_package/input.json",
    "rtl_package/intermediate_reference.json",
    "rtl_package/manifest.json",
    "rtl_package/memory_map.json",
    "rtl_package/model_ir.json",
    "rtl_package/program.json",
    "selected_samples.json",
    "rtl_validation_summary.json",
    "deployment_summary.json",
    "counter_summary.json",
]


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def source_revision(src: Path) -> str:
    repo = src
    while repo != repo.parent and not (repo / ".git").exists():
        repo = repo.parent
    if not (repo / ".git").exists():
        raise SystemExit(f"could not locate SparrowML git repository above {src}")
    proc = subprocess.run(
        ["git", "-C", str(repo), "rev-parse", "HEAD"],
        text=True,
        capture_output=True,
        check=True,
    )
    return proc.stdout.strip()


def build_manifest(src: Path) -> dict:
    files = []
    for rel in TEXT_FILES:
        sp = src / rel
        if not sp.is_file():
            raise SystemExit(f"missing source package file: {sp}")
        dp = DEST / rel
        files.append({
            "path": rel,
            "source_path": f"artifacts/phase8_wisdm/phase8c/{rel}",
            "sha256": sha256(dp if dp.exists() else sp),
            "size_bytes": (dp if dp.exists() else sp).stat().st_size,
        })
    return {
        "format_version": "sparrow_cluster_sparrowml_package_manifest_v1",
        "package": "phase8_wisdm_rtl_package",
        "source_repository": "../sparrow-ml",
        "source_revision": source_revision(src),
        "import_date": date.today().isoformat(),
        "selected_package_path": "artifacts/phase8_wisdm/phase8c/rtl_package",
        "normal_regression_uses_sibling_repository": False,
        "copied_files": files,
        "excluded_files": [
            "phase8b/fp32_checkpoint.pt",
            "phase8b/training_metrics.json",
            "phase8a dataset manifests",
            "rtl_package/model_data.bin",
            "rtl_package/input_data.bin",
            "per-sample logs and duplicate host-run evidence",
        ],
    }


def import_package(src: Path) -> None:
    if not src.is_dir():
        raise SystemExit(f"SparrowML phase8c package directory not found: {src}")
    DEST.mkdir(parents=True, exist_ok=True)
    (DEST / PACKAGE_SRC).mkdir(parents=True, exist_ok=True)
    for rel in TEXT_FILES:
        target = DEST / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src / rel, target)
    manifest = build_manifest(src)
    (DEST / "package_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    provenance = [
        "# SparrowML Provenance",
        "",
        "Frozen package: Phase 8 WISDM RTL package.",
        "Source repository: `../sparrow-ml`.",
        f"Source revision: `{manifest['source_revision']}`.",
        f"Import date: {manifest['import_date']}.",
        "",
        "The import intentionally excludes training checkpoints, datasets, binary mirrors,",
        "per-sample logs, and generated simulator workspaces. Normal Sparrow-Cluster",
        "regressions use only the committed text package files in this directory.",
        "",
    ]
    (DEST / "PROVENANCE.md").write_text("\n".join(provenance), encoding="utf-8")


def load_json(rel: str) -> dict:
    return json.loads((DEST / rel).read_text(encoding="utf-8"))


def check_package() -> dict:
    manifest_path = DEST / "package_manifest.json"
    if not manifest_path.is_file():
        raise SystemExit("missing third_party/sparrowml/package_manifest.json")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for item in manifest["copied_files"]:
        path = DEST / item["path"]
        if not path.is_file():
            raise SystemExit(f"missing imported file: {path.relative_to(ROOT)}")
        if sha256(path) != item["sha256"]:
            raise SystemExit(f"checksum mismatch: {path.relative_to(ROOT)}")
        if path.stat().st_size != item["size_bytes"]:
            raise SystemExit(f"size mismatch: {path.relative_to(ROOT)}")
    m = load_json("rtl_package/manifest.json")
    exp = load_json("rtl_package/expected_output.json")["samples"]
    inter = load_json("rtl_package/intermediate_reference.json")["samples"]
    summary = load_json("deployment_summary.json")
    if summary["selected_sample_count"] != 12 or len(exp) != 12 or len(inter) != 12:
        raise SystemExit("expected exactly 12 selected WISDM samples")
    if not summary["all_valid"]:
        raise SystemExit("SparrowML deployment summary is not valid")
    total = sum(item["size_bytes"] for item in manifest["copied_files"])
    if total > 128 * 1024:
        raise SystemExit(f"imported package too large for responsible commit: {total} bytes")
    package_hashes = m["file_hashes"]
    for required in ("expected_output.json", "input.json", "intermediate_reference.json", "model_ir.json", "program.json"):
        if required not in package_hashes:
            raise SystemExit(f"package manifest missing SparrowML hash for {required}")
    return {"files": len(manifest["copied_files"]), "bytes": total, "samples": len(exp)}


def reference_check() -> dict:
    exp = load_json("rtl_package/expected_output.json")["samples"]
    inter = load_json("rtl_package/intermediate_reference.json")["samples"]
    inputs = load_json("rtl_package/input.json")["samples"]
    by_id = {s["sample_id"]: s for s in inter}
    for sample in exp:
        sid = sample["sample_id"]
        if sid not in by_id:
            raise SystemExit(f"missing intermediate reference for {sid}")
        if sample["fc2_acc_int32"] != by_id[sid]["fc2_acc_int32"]:
            raise SystemExit(f"fc2 mismatch between expected and intermediate references for {sid}")
    if [s["sample_id"] for s in exp] != [s["sample_id"] for s in inputs]:
        raise SystemExit("input and output sample order differ")
    return {
        "prediction_sum": sum(s["predicted_class"] for s in exp),
        "fc2_checksum": sum(sum(s["fc2_acc_int32"]) for s in exp),
        "sample0_prediction": exp[0]["predicted_class"],
    }


def build_metadata() -> None:
    check_package()
    ref = reference_check()
    out = ROOT / "build" / "sparrowml"
    out.mkdir(parents=True, exist_ok=True)
    exp = load_json("rtl_package/expected_output.json")["samples"]
    inter = load_json("rtl_package/intermediate_reference.json")["samples"]
    metadata = {
        "format_version": "sparrow_cluster_sparrowml_build_metadata_v1",
        "sample_count": len(exp),
        "prediction_sum": ref["prediction_sum"],
        "fc2_checksum": ref["fc2_checksum"],
        "sample0": {
            "sample_id": exp[0]["sample_id"],
            "prediction": exp[0]["predicted_class"],
            "fc2_acc_int32": exp[0]["fc2_acc_int32"],
            "hidden_int8_first4": inter[0]["hidden_int8"][:4],
            "fc1_acc_int32_first4": inter[0]["fc1_acc_int32"][:4],
        },
    }
    (out / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("action", choices=["import", "package-check", "import-check", "reference-check", "build"])
    p.add_argument("--source", type=Path, default=DEFAULT_SRC)
    args = p.parse_args()
    if args.action == "import":
        import_package(args.source.resolve())
        info = check_package()
        print(f"sparrowml import: {info['files']} files, {info['bytes']} bytes")
    elif args.action == "import-check":
        for rel in TEXT_FILES:
            if not (args.source / rel).is_file():
                raise SystemExit(f"missing source package file: {args.source / rel}")
        print("sparrowml import check: deterministic source file set available")
    elif args.action == "package-check":
        info = check_package()
        print(f"sparrowml package check: {info['samples']} samples, {info['files']} files, {info['bytes']} bytes")
    elif args.action == "reference-check":
        ref = reference_check()
        print(f"sparrowml reference check: prediction_sum={ref['prediction_sum']} fc2_checksum={ref['fc2_checksum']}")
    elif args.action == "build":
        build_metadata()
        print("sparrowml build: metadata generated in build/sparrowml")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
