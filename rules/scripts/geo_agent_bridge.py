#!/usr/bin/env python3
import os
import sys
import csv
import re
import shutil
import subprocess
import argparse
from pathlib import Path

def parse_metadata_csv(csv_path: Path):
    """Parses GEOAgent/bioStream metadata CSV file."""
    samples = {}
    with open(csv_path, mode="r", encoding="utf-8") as f:
        # Detect delimiter (comma or tab)
        sample_content = f.read(2048)
        f.seek(0)
        dialect = csv.Sniffer().sniff(sample_content) if sample_content.strip() else None
        reader = csv.DictReader(f, dialect=dialect if dialect else 'excel')
        
        # Clean column names
        reader.fieldnames = [name.strip() for name in reader.fieldnames] if reader.fieldnames else []
        
        for row in reader:
            # Skip empty rows
            if not row or not any(row.values()):
                continue
            
            sample_id = row.get("Sample_ID") or row.get("Sample_Name") or row.get("sample")
            srr = row.get("SRR") or row.get("Run") or row.get("SRR_ID")
            aws_url = row.get("SRR_AWS_URL") or row.get("aws_url")
            
            if not sample_id or not srr:
                continue
                
            sample_id = sample_id.strip()
            srr = srr.strip()
            if aws_url:
                aws_url = aws_url.strip()
                
            if sample_id not in samples:
                samples[sample_id] = {
                    "title": row.get("Title", sample_id),
                    "gse": row.get("GSE_ID", "unknown"),
                    "gsm": row.get("GSM_ID", "unknown"),
                    "runs": []
                }
            
            samples[sample_id]["runs"].append({
                "srr": srr,
                "aws_url": aws_url
            })
            
    return samples

def infer_metadata(sample_id: str, title: str):
    """Infers replicate and condition from Title or Sample ID."""
    # Replicate parsing
    rep = 1
    rep_match = re.search(r'(?:rep|replicate)[_-]?(\d+)', title + "_" + sample_id, re.IGNORECASE)
    if rep_match:
        rep = int(rep_match.group(1))
    
    # Condition parsing
    condition = "GEO_sample"
    text = (title + "_" + sample_id).lower()
    
    control_keywords = ["control", "ctrl", "wildtype", "wt", "untreated", "mock", "input", "naive"]
    treated_keywords = ["treated", "knockout", "ko", "tg", "transgenic", "mutant", "mut", "stimulated", "stim"]
    
    for kw in control_keywords:
        if kw in text:
            condition = "control"
            break
    else:
        for kw in treated_keywords:
            if kw in text:
                condition = "treated"
                break
                
    return rep, condition

def check_command(cmd: str) -> bool:
    """Checks if a command-line tool is installed."""
    return shutil.which(cmd) is not None

def download_and_dump(srr: str, aws_url: str, fastq_dir: Path, sra_dir: Path):
    """Downloads SRR file and converts to FASTQ format."""
    os.makedirs(fastq_dir, exist_ok=True)
    os.makedirs(sra_dir, exist_ok=True)
    
    # Target files after fastq-dump/fasterq-dump
    r1_target = fastq_dir / f"{srr}_1.fastq"
    r2_target = fastq_dir / f"{srr}_2.fastq"
    
    if r1_target.exists() and r2_target.exists():
        print(f"FASTQ files for {srr} already exist. Skipping download.")
        return r1_target, r2_target
        
    sra_file = sra_dir / f"{srr}.sra"
    
    # Step 1: Download SRA
    if not sra_file.exists():
        if aws_url:
            print(f"Downloading {srr} SRA file from SRA-AWS link...")
            try:
                subprocess.run(["wget", "-q", "-O", str(sra_file), aws_url], check=True)
            except subprocess.CalledProcessError:
                try:
                    subprocess.run(["curl", "-s", "-L", "-o", str(sra_file), aws_url], check=True)
                except subprocess.CalledProcessError:
                    print(f"Failed to download from SRA AWS URL: {aws_url}")
        
        # Fallback to prefetch if AWS link failed or wasn't provided
        if not sra_file.exists() and check_command("prefetch"):
            print(f"Running prefetch for {srr}...")
            subprocess.run(["prefetch", srr, "-O", str(sra_dir)], check=True)
            # prefetch creates a directory named after srr; locate the sra inside it
            pref_file = sra_dir / srr / f"{srr}.sra"
            if pref_file.exists():
                shutil.move(str(pref_file), str(sra_file))
                shutil.rmtree(str(sra_dir / srr))
                
    # Step 2: Unpack FASTQ
    if sra_file.exists() or check_command("fasterq-dump") or check_command("fastq-dump"):
        input_src = str(sra_file) if sra_file.exists() else srr
        print(f"Extracting FASTQ files for {srr}...")
        
        if check_command("fasterq-dump"):
            subprocess.run(["fasterq-dump", "--split-files", "--outdir", str(fastq_dir), input_src], check=True)
        elif check_command("fastq-dump"):
            subprocess.run(["fastq-dump", "--split-files", "--outdir", str(fastq_dir), input_src], check=True)
            
    # Check extraction results
    if r1_target.exists() and r2_target.exists():
        # Clean up intermediate SRA file to save disk space
        if sra_file.exists():
            sra_file.unlink()
        return r1_target, r2_target
    else:
        raise FileNotFoundError(f"Failed to produce fastq files for run {srr}.")

def merge_fastq_runs(fastq_files: list, output_path: Path):
    """Concatenates multiple fastq files into one file."""
    print(f"Merging fastq files to {output_path}...")
    with open(output_path, 'wb') as outfile:
        for fname in fastq_files:
            with open(fname, 'rb') as infile:
                shutil.copyfileobj(infile, outfile)

def main():
    parser = argparse.ArgumentParser(description="Bridge to import GEOAgent/bioStream metadata and run the BDB ATAC-seq pipeline.")
    parser.add_argument("meta_csv", help="Path to GEOAgent/bioStream ATAC_meta.csv file")
    parser.add_argument("--fastq-dir", default="data/fastq", help="Directory to save fastq files")
    parser.add_argument("--sra-dir", default="data/sra", help="Directory to save temporary SRA files")
    parser.add_argument("--out-samples", default="data/fastp/samples_geo.tsv", help="Output TSV sample sheet path")
    parser.add_argument("--out-config", default="config_geo.yaml", help="Output config yaml file path")
    parser.add_argument("--download", action="store_true", help="Download and extract SRA files automatically")
    
    args = parser.parse_args()
    
    csv_path = Path(args.meta_csv)
    if not csv_path.exists():
        print(f"Error: Metadata file {csv_path} does not exist.")
        sys.exit(1)
        
    print(f"Parsing GEOAgent metadata: {csv_path}")
    samples = parse_metadata_csv(csv_path)
    print(f"Found {len(samples)} unique samples in metadata.")
    
    fastq_dir = Path(args.fastq_dir).resolve()
    sra_dir = Path(args.sra_dir).resolve()
    
    sample_sheet_rows = []
    
    for sample_id, info in samples.items():
        print(f"\nProcessing sample: {sample_id} ({info['title']})")
        rep, condition = infer_metadata(sample_id, info["title"])
        
        # FASTQ paths
        r1_final = fastq_dir / f"{sample_id}_R1.fastq"
        r2_final = fastq_dir / f"{sample_id}_R2.fastq"
        
        if args.download:
            r1_temp_runs = []
            r2_temp_runs = []
            for run in info["runs"]:
                try:
                    r1, r2 = download_and_dump(run["srr"], run["aws_url"], fastq_dir, sra_dir)
                    r1_temp_runs.append(r1)
                    r2_temp_runs.append(r2)
                except Exception as e:
                    print(f"Failed download/extraction for run {run['srr']}: {e}")
                    
            if len(r1_temp_runs) == 1:
                # Direct move/copy to final name
                shutil.move(str(r1_temp_runs[0]), str(r1_final))
                shutil.move(str(r2_temp_runs[0]), str(r2_final))
            elif len(r1_temp_runs) > 1:
                # Merge multiple runs
                merge_fastq_runs(r1_temp_runs, r1_final)
                merge_fastq_runs(r2_temp_runs, r2_final)
                # Clean temp runs
                for f in r1_temp_runs + r2_temp_runs:
                    if f.exists():
                        f.unlink()
        else:
            # Assume local fastq files are already named sample_id_R1.fastq and sample_id_R2.fastq
            # or reference the runs list
            if len(info["runs"]) == 1:
                srr = info["runs"][0]["srr"]
                r1_final = fastq_dir / f"{srr}_1.fastq"
                r2_final = fastq_dir / f"{srr}_2.fastq"
                if not r1_final.exists():
                    r1_final = fastq_dir / f"{sample_id}_R1.fastq"
                    r2_final = fastq_dir / f"{sample_id}_R2.fastq"
            
        # Add to sample sheet rows (use relative paths from project root)
        rel_r1 = os.path.relpath(r1_final, Path.cwd())
        rel_r2 = os.path.relpath(r2_final, Path.cwd())
        
        sample_sheet_rows.append({
            "sample": sample_id,
            "fastq_r1": rel_r1,
            "fastq_r2": rel_r2,
            "replicate": rep,
            "condition": condition
        })
        print(f"Mapped {sample_id} -> R1: {rel_r1}, R2: {rel_r2}, Replicate: {rep}, Condition: {condition}")
        
    # Write TSV Sample Sheet
    out_samples = Path(args.out_samples)
    out_samples.parent.mkdir(parents=True, exist_ok=True)
    with open(out_samples, mode="w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["sample", "fastq_r1", "fastq_r2", "replicate", "condition"], delimiter="\t")
        writer.writeheader()
        writer.writerows(sample_sheet_rows)
    print(f"\nGenerated BDB Sample Sheet: {out_samples}")
    
    # Write Configuration Yaml
    # Load default config.yaml
    default_config_path = Path("config.yaml")
    if default_config_path.exists():
        with open(default_config_path, "r", encoding="utf-8") as f:
            config_data = yaml.safe_load(f) or {}
    else:
        config_data = {}
        
    if "global" not in config_data:
        config_data["global"] = {}
        
    # Override samples path
    rel_samples = os.path.relpath(out_samples, Path.cwd())
    config_data["global"]["samples"] = rel_samples
    
    with open(args.out_config, "w", encoding="utf-8") as f:
        yaml.safe_dump(config_data, f, default_flow_style=False)
    print(f"Generated BDB Configuration file: {args.out_config}")
    
    print("\n" + "="*60)
    print("GEOAgent Integration Bridge Complete!")
    print("To execute the pipeline, run the following command:")
    print(f"snakemake --configfile {args.out_config} --use-conda --cores 8")
    print("="*60)

if __name__ == "__main__":
    main()
