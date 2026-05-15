#!/usr/bin/env python3
import sys
import argparse
import json
from pathlib import Path

# ANSI Color codes for prettier logging
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

def parse_frip(frip_path):
    """Parses FRiP value from file (assumes key\tvalue or tab-separated headered)."""
    try:
        with open(frip_path, 'r') as f:
            lines = [l.strip() for l in f if l.strip()]
            if not lines: return None
            # Check if it has a header 'sample\tfrip'
            if "sample" in lines[0].lower():
                parts = lines[1].split('\t')
                return float(parts[1])
            else:
                parts = lines[0].split('\t')
                return float(parts[1])
    except Exception as e:
        print(f"{Colors.FAIL}Error parsing FRiP: {e}{Colors.ENDC}", file=sys.stderr)
    return None

def parse_tss(tss_path):
    """Parses TSS Enrichment value from the R script output (headered TSV)."""
    try:
        with open(tss_path, 'r') as f:
            lines = [l.strip() for l in f if l.strip()]
            if len(lines) < 2: return None
            parts = lines[1].split('\t')
            if len(parts) >= 2:
                return float(parts[1])
    except Exception as e:
        print(f"{Colors.FAIL}Error parsing TSS Enrichment: {e}{Colors.ENDC}", file=sys.stderr)
    return None

def parse_samtools_stats(stats_path):
    """Parses samtools stats using a robust mapping approach."""
    metrics = {"total_reads": None, "mapped_properly": None, "duplicates": None}
    mapping = {
        "sequences:": "total_reads",
        "properly paired:": "mapped_properly_count",
        "percentage of properly paired reads:": "mapped_properly",
        "reads duplicated:": "duplicates"
    }
    try:
        with open(stats_path, 'r') as f:
            for line in f:
                if not line.startswith("SN\t"): continue
                for key, target in mapping.items():
                    if key in line:
                        val = line.split('\t')[2].replace('%', '').strip()
                        metrics[target] = float(val) if '.' in val else int(val)
    except Exception as e:
        print(f"{Colors.FAIL}Error parsing samtools stats: {e}{Colors.ENDC}", file=sys.stderr)
    return metrics

def main():
    parser = argparse.ArgumentParser(description="Advanced ATAC-seq QC Gating System")
    parser.add_argument("--sample", required=True)
    parser.add_argument("--frip-file", required=True)
    parser.add_argument("--tss-file", required=True)
    parser.add_argument("--stats-file", required=True)
    parser.add_argument("--min-frip", type=float, required=True)
    parser.add_argument("--min-tss", type=float, required=True)
    parser.add_argument("--min-mapping-rate", type=float, required=True)
    parser.add_argument("--max-duplicate-rate", type=float, required=True)
    parser.add_argument("--log", required=True)
    parser.add_argument("--output", required=True)
    
    args = parser.parse_args()
    
    # 1. Parse Data
    frip = parse_frip(args.frip_file)
    tss = parse_tss(args.tss_file)
    stats = parse_samtools_stats(args.stats_file)
    
    # Check for parsing failures
    parse_errors = []
    if frip is None: parse_errors.append("FRiP")
    if tss is None: parse_errors.append("TSS Enrichment")
    if any(v is None for k, v in stats.items() if k != "mapped_properly_count"): 
        parse_errors.append("Samtools Stats")
    
    if parse_errors:
        print(f"{Colors.FAIL}[CRITICAL] Failed to parse: {', '.join(parse_errors)}{Colors.ENDC}", file=sys.stderr)
        sys.exit(1)
        
    # 2. Calculate Derived Metrics
    dup_rate = (stats["duplicates"] * 100.0 / stats["total_reads"]) if stats["total_reads"] > 0 else 100.0
    mapping_rate = stats["mapped_properly"]

    # 3. Validation and Tiering
    qc_data = {
        "sample": args.sample,
        "metrics": {
            "frip": {"val": frip, "target": args.min_frip, "status": "PASS"},
            "tss": {"val": tss, "target": args.min_tss, "status": "PASS"},
            "mapping": {"val": mapping_rate, "target": args.min_mapping_rate, "status": "PASS"},
            "duplicates": {"val": dup_rate, "target": args.max_duplicate_rate, "status": "PASS"}
        },
        "overall": "PASSED"
    }

    def check(metric, val, target, operator='>='):
        warn_threshold = target * 1.1 if operator == '<=' else target * 0.9
        if (operator == '>=' and val < target) or (operator == '<=' and val > target):
            qc_data["metrics"][metric]["status"] = "FAIL"
            qc_data["overall"] = "FAILED"
            return f"{Colors.FAIL}[FAIL] {metric.upper()}: {val:.3f} (Target {operator} {target}){Colors.ENDC}"
        elif (operator == '>=' and val < warn_threshold) or (operator == '<=' and val > warn_threshold):
            qc_data["metrics"][metric]["status"] = "WARN"
            return f"{Colors.WARNING}[WARN] {metric.upper()}: {val:.3f} (Borderline){Colors.ENDC}"
        return f"{Colors.OKGREEN}[PASS] {metric.upper()}: {val:.3f}{Colors.ENDC}"

    # Generate Report Lines
    report = [f"{Colors.BOLD}QC Report for {args.sample}{Colors.ENDC}", "-------------------------------"]
    report.append(check("frip", frip, args.min_frip))
    report.append(check("tss", tss, args.min_tss))
    report.append(check("mapping", mapping_rate, args.min_mapping_rate))
    report.append(check("duplicates", dup_rate, args.max_duplicate_rate, '<='))
    report.append("-------------------------------")
    
    result_color = Colors.OKGREEN if qc_data["overall"] == "PASSED" else Colors.FAIL
    report.append(f"OVERALL RESULT: {result_color}{qc_data['overall']}{Colors.ENDC}")

    # 4. Output Files
    # Text Log
    with open(args.log, 'w') as f:
        # Strip ANSI codes for file output
        clean_report = [line.replace('\033[95m','').replace('\033[94m','').replace('\033[92m','').replace('\033[93m','').replace('\033[91m','').replace('\033[0m','').replace('\033[1m','') for line in report]
        f.write("\n".join(clean_report) + "\n")

    # JSON Data for MultiQC/Dashboard
    with open(Path(args.output).with_suffix('.json'), 'w') as f:
        json.dump(qc_data, f, indent=4)

    # Snakemake Trigger Output
    with open(args.output, 'w') as f:
        f.write(f"{args.sample}\t{qc_data['overall']}\n")

    # Console Output
    print("\n".join(report))
    
    if qc_data["overall"] == "FAILED":
        sys.exit(2)

if __name__ == "__main__":
    main()
