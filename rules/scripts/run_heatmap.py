import os
import gzip
import subprocess
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

# Retrieve variables from snakemake object
filtered_peaks = snakemake.input.filtered_peaks
bigwig = snakemake.input.bigwig
qc_pass = snakemake.input.qc_pass
matrix = snakemake.output.matrix
regions = snakemake.output.regions
plot = snakemake.output.plot

upstream = snakemake.params.upstream
downstream = snakemake.params.downstream
colormap = snakemake.params.colormap

log_matrix = snakemake.log.matrix
log_plot = snakemake.log.plot
threads = snakemake.threads
sample = snakemake.wildcards.sample

# Create directories
os.makedirs(os.path.dirname(matrix), exist_ok=True)
os.makedirs(os.path.dirname(regions), exist_ok=True)
os.makedirs(os.path.dirname(plot), exist_ok=True)

# Check qc_pass status
status = "PASSED"
if os.path.exists(qc_pass):
    with open(qc_pass, 'r') as f:
        line = f.readline().strip()
        if line:
            status = line.split('\t')[1]

# Check if peaks file is empty
is_empty = True
if os.path.exists(filtered_peaks) and os.path.getsize(filtered_peaks) > 0:
    with open(filtered_peaks, 'r') as f:
        for line in f:
            if line.strip():
                is_empty = False
                break

if status == "FAILED" or is_empty:
    import sys
    # Generate empty placeholder files
    with gzip.open(matrix, 'wb') as f:
        pass
    with open(regions, 'w') as f:
        pass
    with open(plot, 'w') as f:
        pass
    with open(log_matrix, 'w') as f:
        f.write(f"QC status: {status}, Peak is_empty: {is_empty}. Generating placeholders.\n")
    sys.exit(0)
else:
    # Run computeMatrix
    cmd_matrix = [
        "computeMatrix", "reference-point",
        "--referencePoint", "center",
        "-b", str(upstream), "-a", str(downstream),
        "-R", filtered_peaks,
        "-S", bigwig,
        "--skipZeros",
        "--missingDataAsZero",
        "--numberOfProcessors", str(threads),
        "-out", matrix,
        "--outFileSortedRegions", regions
    ]
    with open(log_matrix, 'w') as f:
        subprocess.run(cmd_matrix, stdout=f, stderr=f, check=True)
        
    # Run plotHeatmap
    cmd_plot = [
        "plotHeatmap",
        "-m", matrix,
        "-out", plot,
        "--colorMap", colormap,
        "--regionsLabel", "Peak Centers",
        "--samplesLabel", sample,
        "--heatmapHeight", "12", "--heatmapWidth", "6"
    ]
    with open(log_plot, 'w') as f:
        subprocess.run(cmd_plot, stdout=f, stderr=f, check=True)
