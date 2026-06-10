# BDB-Genomics ATAC-seq Pipeline

> **The only ATAC-seq pipeline that stops bad samples before they waste your time and money.**

[![CI](https://github.com/BDB-Genomics/atacseq-pipeline/actions/workflows/lint.yml/badge.svg)](https://github.com/BDB-Genomics/atacseq-pipeline/actions/workflows/lint.yml)
[![Snakemake](https://img.shields.io/badge/Snakemake-≥8.0-blue.svg)](https://snakemake.github.io)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.placeholder.svg)](https://doi.org/10.5281/zenodo.placeholder)

---

## Why This Pipeline

| Problem | Other Pipelines | This Pipeline |
|---|---|---|
| Bad samples run for hours before failing | ❌ Warns after the fact | ✅ **Blocks them immediately** |
| Config errors crash mid-run | ❌ 30 min into a 4-hour job | ✅ **Catches them before starting** |
| Needs a server to run | ❌ 16GB+ RAM required | ✅ **Runs on a 4GB laptop** |
| Hard to set up | ❌ Learn Nextflow, Docker, cloud | ✅ **Edit 2 files, run** |
| Missing ENCODE standards | ⚠️ Some metrics | ✅ **All of them** |

### Gold-Standard Features

- **🛡️ QC Gate** — Samples that fail TSS, FRiP, or mapping thresholds are **blocked** from expensive downstream steps. Other pipelines just warn you.
- **🛡️ Robust Pipeline Safeguards** — Downstream R/Python scripts natively handle zero-count/zero-peak failed samples with dummy placeholder files, guaranteeing the DAG never crashes mid-run. 
- **📦 Immutable Containerization** — Every single rule natively integrates Galaxy Project Singularity containers. Run with `--use-singularity` for 100% OS-agnostic reproducibility without Conda dependency risks.
- **🔍 Pre-Flight Validation** — Catches missing files, bad configs, and sample sheet errors **before** the pipeline starts. Zero wasted compute.
- **💻 Runs Anywhere** — 2GB RAM laptop → 100-node SLURM cluster. One pipeline, four resource profiles.
- **📊 ENCODE-Compliant** — TSS enrichment, FRiP, NSC/RSC, IDR, library complexity, mapping rate, duplicate rate. All included.
- **🧬 Complete Analysis** — Preprocessing → Alignment → Peak Calling → IDR → Footprinting (HINT-ATAC + TOBIAS) → chromVAR → Differential Accessibility → MultiQC report.
- **⚙️ Dynamic Config-Driven** — Every parameter, path, reference genome, and threshold lives in `config.yaml`. No hardcoded reference packages hidden in environments or scripts.

---

## Quick Start (3 Steps)

```bash
# Step 1: Install (one time)
conda create -n atacseq snakemake>=8.0 mamba -c conda-forge -c bioconda
conda activate atacseq

# Step 2: Configure (edit 2 files)
#   → config.yaml       (paths, thresholds, resources)
#   → data/fastp/samples.tsv  (your sample names and FASTQ paths)

# Step 3: Run
snakemake --use-conda --cores 32
```

That's it. The pipeline handles everything else.

### Switch Between Bulk & scATAC-seq (One Command)

```bash
# Bulk ATAC-seq (default)
snakemake --use-conda --cores 32

# Single-cell ATAC-seq
ATAC_MODE=scatac snakemake --use-conda --cores 32

# Or set it in config.yaml:
# global:
#   mode: "scatac"  # or "bulk"
```

**What changes automatically:**

| Step | Bulk Mode | scATAC-seq Mode |
|---|---|---|
| Aligner | Bowtie2 | Chromap (--preset atac) |
| Post-processing | Samtools (sort, fixmate, markdup, view, TN5 shift) | ArchR (Arrow files, doublet filtering) |
| Peak Calling | MACS2 + IDR | ArchR clustering + marker genes |
| Co-accessibility | N/A | Cicero (CCANs, co-accessibility networks) |
| Differential | DESeq2 (bulk samples) | ArchR (per-cluster markers) |
| Footprinting | HINT-ATAC + TOBIAS | chromVAR (bias-corrected) |
| QC Gate | TSS, FRiP, NSC/RSC, mapping, duplicates | TSS, fragments/cell, doublet rate |

---

## Low-Resource Settings

**This pipeline runs on anything.** Choose the profile that matches your machine:

### Profile Comparison

| Your Machine | Profile | RAM Used | Parallel Jobs | Estimated Time |
|---|---|---|---|---|
| ≥16GB RAM, 8+ cores | `profile/local` | 16GB | 8 | ~4 hours |
| ≤8GB RAM, 4 cores | `profile/low_resource` | 8GB | 2 | ~8 hours |
| ≤4GB RAM, 2 cores | `run_batched.py` | 4GB | 1 (sequential) | ~16 hours |
| ≤2GB RAM, 1 core | `--cores 1` | 2GB | 1 | ~24 hours |

### Option 1: Low-Resource Profile (≤8GB RAM)

Built for laptops and small workstations. Caps every rule to safe memory limits and runs max 2 jobs at once.

```bash
snakemake --profile profile/low_resource
```

**What it does automatically:**
- Limits parallel jobs to 2
- Caps Bowtie2 to 4GB RAM, 2 threads
- Caps MACS2 to 4GB RAM, 2 threads
- Caps memory-heavy steps (TSS, DESeq2, TOBIAS) to 4GB
- Falls back to 2GB/1 thread for any unlisted rule

### Option 2: Sequential Batching (≤4GB RAM)

Processes **one sample at a time**. Perfect for machines with very limited memory.

```bash
python3 rules/scripts/run_batched.py --batch-size 1 --cores 2 --memory 4000
```

**How it works:**
1. Reads your sample sheet
2. Runs Sample 1 through the entire pipeline
3. Moves to Sample 2 (reuses results, doesn't re-run Sample 1)
4. Continues until all samples are done
5. Runs final MultiQC aggregation

**Options:**
```bash
# Process 2 samples at a time (if you have 6GB RAM)
python3 rules/scripts/run_batched.py --batch-size 2 --cores 2 --memory 6000

# See what batches will look like without running
python3 rules/scripts/run_batched.py --batch-size 1 --dry-run

# Pass extra snakemake arguments
python3 rules/scripts/run_batched.py --batch-size 1 --cores 2 --memory 4000 -- --keep-going
```

### Option 3: Ultra-Low Resource (≤2GB RAM)

Single-threaded execution with strict memory limits.

```bash
snakemake --cores 1 --resources mem_mb=2000 --profile profile/low_resource
```

### Memory-Saving Tips

If you're still hitting memory limits:

```bash
# Skip heavy visualization steps
snakemake --profile profile/low_resource --exclude-rules heatmap correlation_analysis

# Run only up to peak calling (skip diff accessibility, TOBIAS, chromVAR)
snakemake --profile profile/low_resource \
  results/peak_calling/filtered_peaks/sample1_filtered_peaks.bed

# Resume later — Snakemake remembers what's done
snakemake --profile profile/low_resource --rerun-incomplete
```

### Low-Resource Profile Details

Every rule is capped in `profile/low_resource/config.yaml`:

| Rule | RAM | Threads |
|---|---|---|
| Bowtie2 alignment | 4GB | 2 |
| Samtools sort/markdup | 3-4GB | 2 |
| MACS2 peak calling | 4GB | 2 |
| TSS enrichment (R) | 4GB | 2 |
| TOBIAS footprinting | 4GB | 2 |
| DESeq2 diff accessibility | 4GB | 2 |
| chromVAR analysis | 4GB | 2 |
| MultiQC reporting | 2GB | 1 |
| All other rules | 1-2GB | 1 |

---

## What You Get

After the pipeline finishes, you'll have:

### Quality Control
- **FastQC reports** — Pre/post-trimming quality
- **TSS enrichment score** — Signal-to-noise at transcription start sites
- **FRiP score** — Fraction of reads in peaks (biological enrichment)
- **NSC/RSC** — Strand cross-correlation (ENCODE standard)
- **Library complexity** — Preseq extrapolation
- **Mapping & duplicate rates** — Samtools stats + Picard metrics
- **MultiQC report** — All metrics in one HTML file

### Peaks
- **Per-sample peaks** — MACS2 narrowPeak files
- **IDR-filtered peaks** — Replicate concordance (ENCODE requirement)
- **Consensus peaks** — Merged peak set across all samples
- **Blacklist-filtered peaks** — ENCODE blacklist removed

### Footprinting & Motifs
- **HINT-ATAC footprints** — Per-base TF footprint positions
- **TOBIAS footprints** — Bias-corrected footprint bigwig tracks
- **TOBIAS BINDetect** — Differential TF binding between conditions
- **HOMER motifs** — De novo motif enrichment
- **chromVAR** — Bias-corrected motif accessibility deviations

### Differential Analysis
- **DESeq2 results** — Differentially accessible regions
- **Volcano plot** — Visual summary of significant changes
- **MA plot** — Fold change vs mean expression
- **PCA plot** — Sample clustering
- **Heatmap** — Top variable regions

### Visualization
- **BigWig tracks** — For genome browser viewing
- **CPM-normalized coverage** — Comparable across samples
- **TSS heatmaps** — Signal around transcription start sites
- **Correlation matrix** — Sample-to-sample similarity

### Performance
- **Benchmark summary** — Runtime, memory, and CPU for every rule

---

## scATAC-seq: One-Command Switch

No manual file editing. No Snakefile changes. Just set the mode:

```bash
# Bulk mode (default)
snakemake --use-conda --cores 32

# scATAC-seq mode
ATAC_MODE=scatac snakemake --use-conda --cores 32
```

**What happens automatically:**

| Component | Bulk | scATAC-seq |
|---|---|---|
| Aligner | Bowtie2 | Chromap (`--preset atac`) |
| Post-processing | Samtools (sort/dedup/filter/TN5) | ArchR (Arrow files, doublet filtering) |
| Peak Calling | MACS2 + IDR | ArchR clustering + marker genes |
| Co-accessibility | — | Cicero (CCANs, networks) |
| Differential | DESeq2 | ArchR per-cluster markers |
| Footprinting | HINT-ATAC + TOBIAS | chromVAR |

### Sample Sheet Format

Same TSV format, just add a `barcode` column if you have 10x data:

```tsv
sample	fastq_r1	fastq_r2	replicate	condition	barcode
cell_1	data/scATAC/cell_1_R1.fastq.gz	data/scATAC/cell_1_R2.fastq.gz	1	treated	AAACCTGAGATGCTCA
```

### scATAC-seq Output

After running in `scatac` mode, you get:
- **ArchR**: UMAP clusters, cell type markers, doublet report, QC PDF
- **Cicero**: Co-accessibility connections, CCANs (co-accessibility networks), plot
- **chromVAR**: Bias-corrected motif deviations
- **MultiQC**: Aggregated QC report |

---

## Configuration

### The Only File You Need to Edit

`config.yaml` controls everything. Here's the structure:

```yaml
global:
  samples: "data/fastp/samples.tsv"          # Your sample sheet
  references:
    genome_fa: "data/reference/genome.fa"    # Reference genome
    bowtie2_index: "data/reference/index/genome"  # Bowtie2 index prefix
    blacklist: "data/reference/ENCODE_blacklist.bed"  # ENCODE blacklist
    annotation_gtf: "data/reference/annotation.gtf"   # Gene annotation
    motif_db: "data/motifs/jaspar_vertebrates.meme"   # Motif database

# Every tool follows the same pattern:
fastp:
  output: "results/preprocessing/fastp"
  params:
    trim_front1: 5
    length_required: 30
  threads: 4
  resources:
    mem_mb: 8000
    time: "02:00:00"
```

### QC Gate Thresholds

Change these to match your organism or quality standards:

```yaml
qc_gate:
  params:
    min_frip: 0.2          # Minimum fraction of reads in peaks
    min_tss_enr: 7.0       # Minimum TSS enrichment score
    min_mapping_rate: 80.0 # Minimum mapping percentage
    max_duplicate_rate: 20.0 # Maximum duplicate percentage
```

Samples that fail any threshold **will not proceed** to peak calling or visualization.

---

## Execution Profiles

| Profile | Hardware | Command |
|---|---|---|
| `profile/local` | ≥16GB RAM, 8+ cores | `snakemake --profile profile/local` |
| `profile/slurm` | HPC cluster (100+ jobs) | `snakemake --profile profile/slurm` |
| `profile/low_resource` | ≤8GB RAM, 2-4 cores | `snakemake --profile profile/low_resource` |
| `profile/test` | CI validation | `snakemake --profile profile/test --cores 4` |

### HPC (SLURM) Setup

1. Edit `profile/slurm/config.yaml`:
   ```yaml
   slurm_partition: "your_partition"   # Your cluster partition
   slurm_account: "your_account"       # Your billing account
   ```

2. Run:
   ```bash
   snakemake --profile profile/slurm
   ```

---

## Comparison with Established Pipelines

| Feature | BDB-Genomics | nf-core/atacseq | ENCODE |
|---|---|---|---|
| **QC execution gating** | ✅ Blocks downstream | ⚠️ Warns only | ⚠️ Manual |
| **Pre-flight validation** | ✅ Catches errors before DAG | ❌ Fails mid-run | ❌ |
| **Config-driven architecture** | ✅ 100% dynamic | ⚠️ Partial | ❌ Hardcoded |
| **IDR replicate concordance** | ✅ | ✅ | ✅ Required |
| **NSC/RSC cross-correlation** | ✅ | ✅ | ✅ Required |
| **Consensus peak calling** | ✅ | ✅ | ✅ |
| **Differential accessibility** | ✅ DESeq2 | ✅ DESeq2 | ✅ |
| **Footprinting** | ✅ HINT-ATAC + TOBIAS | ✅ HINT-ATAC + TOBIAS | ✅ HINT-ATAC |
| **Motif bias correction** | ✅ chromVAR | ✅ chromVAR | ✅ |
| **Benchmark aggregation** | ✅ Built-in | ❌ | ❌ |
| **Low-resource mode** | ✅ 3 profiles + batched runner | ❌ | ❌ |
| **scATAC-seq (built-in)** | ✅ Chromap + ArchR + Cicero | ✅ CellRanger + ArchR | ❌ |
| **Co-accessibility (Cicero)** | ✅ | ❌ | ❌ |
| **Bulk ↔ scATAC-seq switch** | ✅ One CLI flag | ❌ Separate pipelines | ❌ |
| **Setup complexity** | Edit 2 files | Learn DSL2 + Nextflow | Docker + complex configs |
| **Cloud deployment** | ❌ | ✅ AWS/GCP/Azure | ✅ |

---

## Repository Structure

```
├── Snakefile                    # Main entry point
├── config.yaml                  # Single source of truth
├── profile/                     # Execution profiles
│   ├── local/config.yaml        # Workstation (8 jobs)
│   ├── slurm/config.yaml        # HPC cluster (100 jobs)
│   ├── low_resource/config.yaml # Laptop (2 jobs, capped memory)
│   └── test/config.yaml         # CI validation
├── rules/                       # 40+ modular rule files
│   ├── envs/                    # 22 conda environments
│   ├── scripts/                 # Custom R/Python scripts
│   └── config/                  # MultiQC configuration
├── data/                        # Reference data and sample sheets
└── .github/workflows/           # CI/CD (lint + test)
```

---

## Adding a New Tool

1. Copy `rules/template_tool.smk` → `rules/your_tool.smk`
2. Create `rules/envs/XX_category/your_tool.yaml`
3. Add `include: "rules/your_tool.smk"` to Snakefile
4. Add targets to the appropriate `*_TARGETS` list
5. Add config block to `config.yaml`

That's it. The pipeline picks it up automatically.

---

## Citation

Bhandary, H. (2026). *BDB-Genomics ATAC-seq Framework (Version 2.1.0)*. BDB-Genomics GitHub Repository. https://github.com/BDB-Genomics/atacseq-pipeline

## License

MIT License — see `LICENSE` file for details.
