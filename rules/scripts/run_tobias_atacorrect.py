import os
import subprocess
import shutil

bam = snakemake.input.bam
peaks = snakemake.input.peaks
genome = snakemake.input.genome
blacklist = snakemake.input.blacklist

corrected_bw = snakemake.output.corrected_bw
bias_track = snakemake.output.bias_track
log_file = snakemake.output.log_file

genome_sizes = snakemake.params.genome_sizes
out_dir = snakemake.params.out_dir
threads = snakemake.threads
sample = snakemake.wildcards.sample
log_err = snakemake.log[0]

# Create directories
os.makedirs(os.path.dirname(corrected_bw), exist_ok=True)
os.makedirs(os.path.dirname(bias_track), exist_ok=True)
os.makedirs(os.path.dirname(log_file), exist_ok=True)

# Check if peaks file is empty
is_empty = True
if os.path.exists(peaks) and os.path.getsize(peaks) > 0:
    with open(peaks, 'r') as f:
        for line in f:
            if line.strip():
                is_empty = False
                break

if is_empty:
    import sys
    with open(log_err, 'a') as log_f:
        log_f.write(f"[ERROR] No peaks found in {peaks}. Cannot run TOBIAS ATACorrect.\n")
    sys.exit(1)
else:
    # Run TOBIAS ATACorrect
    cmd = [
        "TOBIAS", "ATACorrect",
        "--bam", bam,
        "--genome", genome,
        "--peaks", peaks,
        "--blacklist", blacklist,
        "--outdir", out_dir,
        "--prefix", sample,
        "--cores", str(threads)
    ]
    with open(log_file, 'w') as out_f:
        subprocess.run(cmd, stdout=out_f, stderr=subprocess.STDOUT, check=True)
        
    # Copy log_file to log_err
    shutil.copy(log_file, log_err)
    
    # If output files are not in the exact target path, move them
    expected_corrected = os.path.join(out_dir, f"{sample}_corrected.bw")
    expected_bias = os.path.join(out_dir, f"{sample}_bias.bw")
    
    if expected_corrected != corrected_bw:
        shutil.move(expected_corrected, corrected_bw)
    if expected_bias != bias_track:
        shutil.move(expected_bias, bias_track)
