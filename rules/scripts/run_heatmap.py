import os
import gzip
import subprocess
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

# Retrieve variables from snakemake object
filtered_peaks = snakemake.input.filtered_peaks
bigwig = snakemake.input.bigwig
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

# Check if peaks file is empty
is_empty = True
if os.path.exists(filtered_peaks) and os.path.getsize(filtered_peaks) > 0:
    with open(filtered_peaks, 'r') as f:
        for line in f:
            if line.strip():
                is_empty = False
                break

if is_empty:
    import sys
    with open(log_matrix, 'w') as f:
        f.write("[ERROR] Peak file is empty. Cannot generate heatmap.\n")
    sys.exit(1)
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
