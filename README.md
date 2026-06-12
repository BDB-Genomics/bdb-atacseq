# BDB-Genomics ATAC-seq Pipeline

A production-grade, config-driven Snakemake framework for end-to-end ATAC-seq analysis. Built for resilience, it supports both bulk and single-cell modalities, automatically scales from 4GB laptops to HPC clusters, and implements strict Quality Control gating to halt poor samples before downstream processing.

[![CI](https://github.com/BDB-Genomics/atacseq-pipeline/actions/workflows/lint.yml/badge.svg)](https://github.com/BDB-Genomics/atacseq-pipeline/actions/workflows/lint.yml)
[![Snakemake](https://img.shields.io/badge/Snakemake-%E2%89%A58.0-blue.svg)](https://snakemake.github.io)

---

## 1. Quick Start

### Installation
The pipeline handles all tool dependencies internally via Conda and Singularity.
```bash
conda create -n atacseq snakemake>=8.0 -c conda-forge -c bioconda
conda activate atacseq
```

### Execution
```bash
# Standard Bulk run (8 cores)
snakemake --use-conda --cores 8

# Single-cell ATAC run
ATAC_MODE=scatac snakemake --use-conda --cores 8

# Reproducible run using Singularity containers instead of Conda
snakemake --use-singularity --cores 8
```

---

## 2. Configuration & Profiles

The pipeline is completely configuration-driven. You never need to modify the underlying Snakemake rules.

### The Source of Truth: `config.yaml`
Every file path, genome size, and thread count is defined here. For example, MACS2 dynamically computes the genome size at parse time:
```python
# The pipeline automatically parses the genome size from your reference files:
gsize=sum(int(line.strip().split()[1]) for line in open(config['global']['references']['genome_sizes']))
```

### Dynamic Configuration Overrides
You can override specific parameters on the fly without touching the main `config.yaml` file. The pipeline safely merges your overrides into memory.
```yaml
# custom_override.yaml
qc_gate:
  params:
    min_frip: 0.0  # Turn off FRiP requirement for a quick test
```
```bash
# Snakemake natively merges files from left to right
snakemake --configfile config.yaml custom_override.yaml --cores 8
```

### Hardware Profiles
Pre-built profiles adapt the pipeline to your hardware:
* **Local:** `snakemake --profile profile/local` (8 parallel jobs)
* **SLURM/HPC:** `snakemake --profile profile/slurm` (100 parallel jobs)
* **Low-Resource (Laptops):** `snakemake --profile profile/low_resource` (Caps every rule to 4GB memory limits)
* **Ultra-Low Memory:** `python3 rules/scripts/run_batched.py --batch-size 2` (Processes 2 samples at a time sequentially)

---

## 3. Pipeline Architecture

Switching the `ATAC_MODE` environment variable dictates which analysis tracks are executed:

| Stage | Bulk Mode (`bulk`) | Single-Cell Mode (`scatac`) |
| :--- | :--- | :--- |
| **Alignment** | Bowtie2 (`--very-sensitive`) | Chromap (`--preset atac`) |
| **Filtering** | MAPQ > 30, Fixmate, ENCODE Blacklist removal, Tn5 Shift | ArchR Arrow creation & doublet removal |
| **Peak Calling** | MACS2, IDR replicate concordance | ArchR marker peak identification |
| **Co-accessibility**| N/A | Cicero (500bp window, 250kb distance) |
| **Differential** | DESeq2 (FDR 0.05, log2FC 1.0) | ArchR cluster markers |
| **Footprinting** | HINT-ATAC & TOBIAS BINDetect | chromVAR motif accessibility |

---

## 4. Quality Control & Fail-Safes

### The QC Gate
The pipeline implements a hard gate (`rules/scripts/parse_qc_metrics.py`) before peak calling. Samples must pass four strict thresholds (configurable in `config.yaml`):
1. **FRiP Score:** $\ge 0.2$
2. **TSS Enrichment:** $\ge 7.0$
3. **Mapping Rate:** $\ge 80.0\%$
4. **Duplicate Rate:** $\le 20.0\%$

Samples that fail are documented in `{sample}_qc_pass.txt` and automatically bypassed for downstream footprinting/differential analysis to save compute time.

### Graceful Fallbacks for Empty Samples
If a sample passes the gate but yields **zero peaks** after blacklist filtering, downstream rules (ChIPseeker, heatmaps, TOBIAS) will automatically detect the empty file. Rather than crashing the DAG, they utilize single-line Python routines to instantly generate valid dummy outputs (e.g., empty DataFrames, blank PDFs) and proceed.

---

## 5. Output Manifest

All outputs are written to the `results/` directory, cleanly organized by stage:

* **`results/alignment/`**: Post-filtered, sorted, and Tn5-shifted BAMs.
* **`results/metrics_qc/`**: MultiQC HTML report aggregating FastQC, Preseq, Picard, and the QC Gate JSONs.
* **`results/peak_calling/`**: MACS2 narrowPeaks, consensus BEDs, and IDR sets.
* **`results/differential/`**: DESeq2 tables, Volcano/MA/PCA plots.
* **`results/footprinting/`**: TOBIAS bias-corrected BigWigs and BINDetect motif plots.
* **`benchmarks/`**: Memory and CPU time consumption for every single job executed.

---
**Citation:** Bhandary, H. (2026). *BDB-Genomics ATAC-seq Framework (Version 3.0.0).*
