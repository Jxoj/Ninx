#!/usr/bin/env python3
"""
build_pkg.py  Ninx Package Builder
Usage: python3 build_pkg.py <devpkgs_dir>

Reads nambuild.json from <devpkgs_dir> for global config:
{
  "Author":     "Jxoj",
  "Version":    "1.0.0",
  "OutputPath": "/path/to/output/",   (where .zip files are placed)
  "JsonPath":   "/path/to/pkgs.json"  (repo JSON to update)
}

For each subfolder in <devpkgs_dir>:
  - Folder name = package name
  - Package ID  = first 10 chars of name, lowercase, alphanumeric only
  - Creates com.(Author).(pkgid).json inside the folder
  - Zips folder contents (STORE method) to OutputPath/(name).zip
  - Updates JsonPath with the package entry (or overrides existing by id)
"""

import os
import sys
import json
import re
import zipfile
import shutil
from pathlib import Path

def make_pkg_id(name: str) -> str:
    """Generate package ID: first 10 alphanumeric chars of name, lowercase."""
    clean = re.sub(r"[^a-zA-Z0-9]", "", name)
    return clean[:10].lower()

def read_nambuild(devpkgs_dir: Path) -> dict:
    nb_path = devpkgs_dir / "nambuild.json"
    if not nb_path.exists():
        print(f"[Warn] No nambuild.json found in {devpkgs_dir}. Using defaults.")
        return {}
    try:
        with open(nb_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except json.decoder.JSONDecodeError as e:
        print(f"[Error] Malformed JSON in {nb_path}: {e}")
        print("Please check for trailing commas or other syntax errors.")
        sys.exit(1)

def load_repo_json(path: Path) -> list:
    if not path.exists():
        return []
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
            return data if isinstance(data, list) else []
    except json.decoder.JSONDecodeError:
        print(f"[Warn] {path} is empty or malformed. Starting fresh.")
        return []

def save_repo_json(path: Path, data: list):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    print(f"  [OK] Updated repo JSON: {path}")

def write_pkg_meta(pkg_dir: Path, pkg_id: str, author: str, version: str, name: str):
    meta_name = f"com.{author}.{pkg_id}.json"
    meta = {
        "id":      pkg_id,
        "name":    name,
        "author":  author,
        "version": version,
    }
    meta_path = pkg_dir / meta_name
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)
    print(f"  [OK] Wrote metadata: {meta_name}")

def build_zip(pkg_dir: Path, output_path: Path, pkg_name: str) -> Path:
    """Create a STORE-mode ZIP of pkg_dir contents."""
    output_path.mkdir(parents=True, exist_ok=True)
    zip_file = output_path / f"{pkg_name}.zip"

    with zipfile.ZipFile(zip_file, "w", compression=zipfile.ZIP_STORED) as zf:
        for item in pkg_dir.rglob("*"):
            if item.is_file():
                arcname = item.relative_to(pkg_dir)
                zf.write(item, arcname)

    print(f"  [OK] Built ZIP: {zip_file}")
    return zip_file

def update_repo(repo_data: list, pkg_id: str, pkg_name: str, author: str, version: str,
                description: str, zip_url: str) -> list:
    entry = {
        "id":          pkg_id,
        "name":        pkg_name,
        "author":      author,
        "version":     version,
        "description": description,
        "zip":         zip_url,
    }
    # Override existing entry with same id
    for i, existing in enumerate(repo_data):
        if existing.get("id") == pkg_id:
            repo_data[i] = entry
            print(f"  [OK] Updated existing entry for '{pkg_id}' in repo.")
            return repo_data
    repo_data.append(entry)
    print(f"  [OK] Added new entry for '{pkg_id}' to repo.")
    return repo_data

def build_package(pkg_dir: Path, config: dict, repo_data: list) -> dict | None:
    pkg_name   = pkg_dir.name
    pkg_id     = make_pkg_id(pkg_name)
    author     = config.get("Author",  "unknown")
    version    = config.get("Version", "1.0.0")
    output_dir = Path(config.get("OutputPath", str(pkg_dir.parent / "output")))

    # Read per-package nambuild.json override if present
    per_pkg_cfg_path = pkg_dir / "nambuild.json"
    if per_pkg_cfg_path.exists():
        try:
            with open(per_pkg_cfg_path, "r", encoding="utf-8") as f:
                per_cfg = json.load(f)
            author  = per_cfg.get("Author",  author)
            version = per_cfg.get("Version", version)
        except Exception as e:
            print(f"  [Warn] Could not read per-package nambuild.json: {e}")

    description = config.get("Description", "")

    print(f"\n[Package] {pkg_name} (id={pkg_id}, author={author}, version={version})")

    # Write metadata file inside package dir
    write_pkg_meta(pkg_dir, pkg_id, author, version, pkg_name)

    # Build ZIP
    zip_file = build_zip(pkg_dir, output_dir, pkg_name)

    # The zip URL in the repo JSON — placeholder that user must update,
    # or auto-set if a base URL is configured.
    base_url = config.get("BaseUrl", "")
    zip_url  = (base_url.rstrip("/") + "/" + pkg_name + ".zip") if base_url else f"<set zip url for {pkg_name}>"

    return {
        "id": pkg_id, "name": pkg_name, "author": author,
        "version": version, "description": description, "zip": zip_url
    }

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 build_pkg.py <devpkgs_dir>")
        sys.exit(1)

    devpkgs_dir = Path(sys.argv[1]).resolve()
    if not devpkgs_dir.is_dir():
        print(f"Error: '{devpkgs_dir}' is not a directory.")
        sys.exit(1)

    config = read_nambuild(devpkgs_dir)
    json_path_str = config.get("JsonPath", "")
    json_path = Path(json_path_str) if json_path_str else None

    repo_data = load_repo_json(json_path) if json_path else []

    built = 0
    for item in sorted(devpkgs_dir.iterdir()):
        # Skip non-directories and nambuild.json
        if not item.is_dir():
            continue
        # Skip hidden dirs
        if item.name.startswith("."):
            continue

        result = build_package(item, config, repo_data)
        if result:
            if json_path:
                repo_data = update_repo(
                    repo_data,
                    result["id"], result["name"], result["author"],
                    result["version"], result["description"], result["zip"]
                )
            built += 1

    if json_path and built > 0:
        save_repo_json(json_path, repo_data)

    print(f"\n[Done] Built {built} package(s).")
    if not json_path:
        print("[Note] No JsonPath configured — repo JSON not updated.")
    if not config.get("BaseUrl"):
        print("[Note] No BaseUrl configured in nambuild.json — zip URLs will be placeholder values.")
        print("       Add 'BaseUrl': 'https://yourhost.com/pkgs/' to nambuild.json.")

if __name__ == "__main__":
    main()
