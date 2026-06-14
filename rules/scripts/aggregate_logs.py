import os
import json
import sys
import glob
import csv
from datetime import datetime

def parse_benchmarks(benchmark_file):
    benchmarks = []
    if os.path.exists(benchmark_file):
        with open(benchmark_file, 'r') as f:
            reader = csv.DictReader(f, delimiter='\t')
            for row in reader:
                benchmarks.append(row)
    return benchmarks

def is_actual_error(line):
    line_lower = line.lower()
    # Check if we have error-like keywords
    has_error_keyword = any(k in line_lower for k in ['error', 'exception', 'failed', 'fatal', 'critical'])
    if not has_error_keyword:
        return False
        
    # Filter out common false positive messages (e.g. "0 errors")
    false_positives = [
        '0 error', 'no error', 'zero error', 'error rate: 0', 'errors: 0',
        'no exception', '0 exception', 'exception: none', 'successful',
        '0 failed', 'no failed', 'errors = 0'
    ]
    if any(fp in line_lower for fp in false_positives):
        return False
        
    return True

def extract_errors(logs_dir):
    errors = []
    if not os.path.exists(logs_dir):
        return errors
        
    for filepath in glob.glob(f"{logs_dir}/**/*.log", recursive=True):
        with open(filepath, 'r') as f:
            lines = f.readlines()
            error_lines = [l.strip() for l in lines if is_actual_error(l)]
            if error_lines:
                rule_name = os.path.basename(os.path.dirname(filepath))
                sample_name = os.path.basename(filepath).replace('.log', '')
                errors.append({
                    "rule": rule_name,
                    "target": sample_name,
                    "log_file": filepath,
                    "error_snippets": error_lines[-5:] # last 5 actual error mentions
                })
    return errors

def main():
    if len(sys.argv) < 3:
        print("Usage: python aggregate_logs.py <status: success/error> <output_json>")
        sys.exit(1)
        
    status = sys.argv[1]
    output_json = sys.argv[2]
    
    summary = {
        "timestamp": datetime.now().isoformat(),
        "status": status,
        "performance_metrics": parse_benchmarks("results/reporting/benchmark_summary.tsv"),
        "errors": extract_errors("logs") if status == "error" else []
    }
    
    os.makedirs(os.path.dirname(output_json), exist_ok=True)
    with open(output_json, 'w') as f:
        json.dump(summary, f, indent=4)
        
    print(f"Aggregated pipeline execution summary written to {output_json}")

if __name__ == "__main__":
    main()
