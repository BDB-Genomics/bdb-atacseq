#!/usr/bin/env python3
import os
import sys
import yaml
import json
import argparse
import subprocess
from pathlib import Path

# Try importing requests, install or handle if missing
try:
    import requests
except ImportError:
    print("This script requires the 'requests' library.")
    print("Please run: pip install requests")
    sys.exit(1)

def parse_cff_metadata(cff_path: Path):
    """Parses citation metadata from CITATION.cff using yaml."""
    if not cff_path.exists():
        return {}
        
    with open(cff_path, "r", encoding="utf-8") as f:
        try:
            cff = yaml.safe_load(f) or {}
        except Exception as e:
            print(f"Warning: Failed to parse CITATION.cff: {e}")
            return {}
            
    creators = []
    for author in cff.get("authors", []):
        name = ""
        if "family-names" in author and "given-names" in author:
            name = f"{author['family-names']}, {author['given-names']}"
        elif "name" in author:
            name = author["name"]
        
        if name:
            creator = {"name": name}
            if "affiliation" in author:
                creator["affiliation"] = author["affiliation"]
            creators.append(creator)
            
    # Default to open-access / MIT license mapping
    license_val = cff.get("license", "mit").lower()
    if license_val == "mit":
        license_val = "MIT"
        
    metadata = {
        "title": cff.get("title", "BDB-Genomics ATAC-seq Framework"),
        "description": cff.get("abstract", "A production-grade, modular, and containerized Snakemake framework for end-to-end ATAC-seq data analysis."),
        "upload_type": "software",
        "creators": creators or [{"name": "Bhandary, Himanshu", "affiliation": "BDB-Genomics"}],
        "version": str(cff.get("version", "3.0.0")),
        "license": license_val,
        "keywords": cff.get("keywords", ["ATAC-seq", "Snakemake", "Genomics"])
    }
    return metadata

def create_archive(proj_root: Path, archive_path: Path):
    """Creates a clean zip archive of the repository using git archive."""
    print("Creating repository archive using git archive...")
    try:
        subprocess.run(
            ["git", "archive", "--format=zip", "HEAD", "-o", str(archive_path)],
            cwd=str(proj_root),
            check=True
        )
        print(f"Archive created at {archive_path}")
    except subprocess.CalledProcessError as e:
        print(f"Error creating git archive: {e}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="Create a draft deposition on Zenodo or Zenodo Sandbox using CITATION.cff metadata.")
    parser.add_argument("--token", help="Zenodo Personal Access Token (can also be set via ZENODO_TOKEN env var)")
    parser.add_argument("--production", action="store_true", help="Upload to production Zenodo (defaults to sandbox)")
    parser.add_argument("--publish", action="store_true", help="Automatically publish the deposition (Warning: this is irreversible!)")
    parser.add_argument("--archive", default="bdb_atacseq_pipeline.zip", help="Path to save the generated zip archive")
    
    args = parser.parse_args()
    
    token = args.token or os.environ.get("ZENODO_TOKEN")
    if not token:
        print("Error: Zenodo Personal Access Token is required.")
        print("Set it using the --token argument or the ZENODO_TOKEN environment variable.")
        print("\nTo generate a token:")
        print("1. Go to https://sandbox.zenodo.org/account/settings/applications/ (Sandbox) or https://zenodo.org/account/settings/applications/ (Production)")
        print("2. Create a new token with 'deposit:actions' and 'deposit:write' scopes.")
        sys.exit(1)
        
    base_url = "https://zenodo.org/api" if args.production else "https://sandbox.zenodo.org/api"
    print(f"Targeting Zenodo Server: {base_url}")
    
    proj_root = Path(__file__).resolve().parents[2]
    archive_path = Path(args.archive).resolve()
    
    # 1. Package repository
    create_archive(proj_root, archive_path)
    
    # 2. Extract metadata
    metadata = parse_cff_metadata(proj_root / "CITATION.cff")
    
    # 3. Create deposition draft
    headers = {"Content-Type": "application/json"}
    params = {"access_token": token}
    
    print("Creating new draft deposition...")
    r = requests.post(f"{base_url}/deposit/depositions", params=params, json={}, headers=headers)
    if r.status_code != 201:
        print(f"Failed to create deposition: {r.status_code}")
        print(r.text)
        sys.exit(1)
        
    dep_data = r.json()
    dep_id = dep_data["id"]
    bucket_url = dep_data["links"]["bucket"]
    
    print(f"Deposition created with ID: {dep_id}")
    
    # 4. Upload file
    print(f"Uploading {archive_path.name} to Zenodo...")
    with open(archive_path, "rb") as fp:
        upload_r = requests.put(
            f"{bucket_url}/{archive_path.name}",
            data=fp,
            params=params
        )
    if upload_r.status_code != 200 and upload_r.status_code != 201:
        print(f"Upload failed: {upload_r.status_code}")
        print(upload_r.text)
        sys.exit(1)
    print("Upload completed successfully.")
    
    # Clean up archive
    if archive_path.exists():
        archive_path.unlink()
        
    # 5. Update deposition metadata
    print("Submitting CITATION.cff metadata...")
    update_data = {"metadata": metadata}
    meta_r = requests.put(
        f"{base_url}/deposit/depositions/{dep_id}",
        params=params,
        json=update_data,
        headers=headers
    )
    if meta_r.status_code != 200:
        print(f"Failed to update metadata: {meta_r.status_code}")
        print(meta_r.text)
        sys.exit(1)
    print("Metadata updated successfully.")
    
    # Get direct links
    html_url = dep_data["links"]["html"]
    print("\n" + "="*60)
    print("Zenodo Deposition Draft Created Successfully!")
    print(f"Draft ID: {dep_id}")
    print(f"Review and Edit URL: {html_url}")
    print("="*60)
    
    # 6. Optional publish
    if args.publish:
        confirm = input("\nAre you absolutely sure you want to PUBLISH this deposition? This is IRREVERSIBLE. (y/N): ")
        if confirm.lower() == 'y':
            print("Publishing deposition...")
            pub_r = requests.post(f"{base_url}/deposit/depositions/{dep_id}/actions/publish", params=params)
            if pub_r.status_code != 202:
                print(f"Publish failed: {pub_r.status_code}")
                print(pub_r.text)
                sys.exit(1)
            pub_data = pub_r.json()
            doi = pub_data.get("doi")
            print(f"Deposition published successfully! DOI: {doi}")
        else:
            print("Publication skipped.")

if __name__ == "__main__":
    main()
