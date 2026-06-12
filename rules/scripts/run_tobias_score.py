import os
import subprocess

corrected_bw = snakemake.input.corrected_bw
peaks = snakemake.input.peaks
footprint_bw = snakemake.output.footprint_bw

genome_sizes = snakemake.params.genome_sizes
out_dir = snakemake.params.out_dir
threads = snakemake.threads
log_err = snakemake.log[0]

# Create directories
os.makedirs(os.path.dirname(footprint_bw), exist_ok=True)

# Check if peaks file is empty
is_empty = True
if os.path.exists(peaks) and os.path.getsize(peaks) > 0:
    with open(peaks, 'r') as f:
        for line in f:
            if line.strip():
                is_empty = False
                break

if is_empty:
    with open(log_err, 'a') as log_f:
        log_f.write(f"[WARNING] No peaks found in {peaks}. Creating dummy footprint bigWig file.\n")
        
    headers = []
    with open(genome_sizes) as f:
        for line in f:
            if line.strip():
                parts = line.strip().split()
                headers.append((parts[0], int(parts[1])))
                
    import pyBigWig
    bw = pyBigWig.open(footprint_bw, 'w')
    bw.addHeader(headers)
    bw.addEntries([headers[0][0]], [0], ends=[100], values=[0.0])
    bw.close()
else:
    # Run TOBIAS FootprintScores
    cmd = [
        "TOBIAS", "FootprintScores",
        "--signal", corrected_bw,
        "--regions", peaks,
        "--output", footprint_bw,
        "--cores", str(threads)
    ]
    with open(log_err, 'w') as log_f:
        subprocess.run(cmd, stdout=log_f, stderr=subprocess.STDOUT, check=True)
