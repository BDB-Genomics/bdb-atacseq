# BDB-Genomics ATAC-seq Pipeline (V2.0.0)

> **A production-grade, ENCODE-compliant Snakemake framework for bulk ATAC-seq analysis.**
> 
> _Looking for single-cell ATAC-seq (scATAC-seq) analysis?_ See the [scATAC-seq Guide](#scatac-seq-guide) below for switching this pipeline to single-cell mode.

---

## Quick Start

```bash
# 1. Install
conda create -n atacseq snakemake>=8.0 mamba -c conda-forge -c bioconda
conda activate atacseq

# 2. Configure
# Edit config.yaml and data/fastp/samples.tsv

# 3. Dry-run
snakemake -n --use-conda

# 4. Run
snakemake --use-conda --cores 32

# 5. HPC (SLURM)
snakemake --profile profile/slurm
```

---

## scATAC-seq Guide

This pipeline is **bulk ATAC-seq by default** but can be adapted for single-cell analysis with three changes:

### Step 1: Update the Sample Sheet

Replace `data/fastp/samples.tsv` with a **per-barcode manifest**:

```tsv
sample	fastq_r1	fastq_r2	replicate	condition	barcode
cell_1	data/scATAC/cell_1_R1.fastq.gz	data/scATAC/cell_1_R2.fastq.gz	1	treated	AAACCTGAGATGCTCA
cell_2	data/scATAC/cell_2_R1.fastq.gz	data/scATAC/cell_2_R2.fastq.gz	1	treated	AAACCTGAGCGTATAC
cell_3	data/scATAC/cell_3_R1.fastq.gz	data/scATAC/cell_3_R2.fastq.gz	2	control	AAACCTGAGTCCGCTA
```

### Step 2: Swap the Aligner

Replace Bowtie2 with **Chromap** or **CellRanger-ATAC** in `config.yaml`:

```yaml
# Option A: Chromap (fast, recommended for scATAC-seq)
chromap:
  input: "results/preprocessing/fastp"
  output: "results/alignment/chromap"
  params:
    index: "data/reference/index/genome.idx"
    preset: "atac"
  threads: 16
  resources:
    mem_mb: 32000
    time: "02:00:00"

# Option B: CellRanger-ATAC (10x Genomics official)
cellranger_atac:
  input: "results/preprocessing/fastp"
  output: "results/alignment/cellranger"
  params:
    reference: "data/reference/cellranger_ref"
    expect_cells: 5000
  threads: 16
  resources:
    mem_mb: 64000
    time: "04:00:00"
```

Then update the Snakefile:
```python
# Replace:
include: "rules/bowtie2.smk"
# With:
include: "rules/chromap.smk"  # or cellranger_atac.smk
```

### Step 3: Swap the Peak Caller

Replace MACS2 with **MACS3** or **ArchR/SnapATAC2** for single-cell:

```yaml
# MACS3 (bulk-like, works for pseudo-bulk)
macs3:
  input: "results/post_alignment/tn5_shift"
  output: "results/peak_calling/macs3"
  params:
    genome_size: "hs"
    qvalue: 0.01
  threads: 8

# For true single-cell: use ArchR (R) or SnapATAC2 (Python)
# These require separate rule files — see rules/template_tool.smk as a starting point
```

### Recommended scATAC-seq Tools

| Step | Bulk (Default) | scATAC-seq Alternative |
|---|---|---|
| Alignment | Bowtie2 | Chromap, CellRanger-ATAC |
| Peak Calling | MACS2 | MACS3 (pseudo-bulk), ArchR, SnapATAC2 |
| Motif Analysis | HOMER | chromVAR (already included) |
| Differential Accessibility | DESeq2 | Signac, ArchR, SnapATAC2 |
| Clustering | N/A | Seurat, ArchR, SnapATAC2 |

### Full scATAC-seq Workflow

For production single-cell analysis, we recommend:

1. **10x Genomics data**: Use `cellranger-atac count` → then run this pipeline on the resulting BAM for QC
2. **Non-10x data**: Use [SnapATAC2](https://github.com/kaizhang/SnapATAC2) or [ArchR](https://www.archrproject.com/) for the full single-cell workflow
3. **Hybrid approach**: Run this pipeline for QC metrics (TSS, FRiP, NSC/RSC) on pseudo-bulk samples, then use ArchR/SnapATAC2 for clustering and differential accessibility

---

## Pipeline Architecture

```
Preprocessing → Alignment → Post-Alignment → QC Metrics → QC Gate
                                                         ↓
                                          Visualization ← Peak Calling
                                                         ↓
                                          Differential Accessibility
```

### Stage Details

| Stage | Tools | Output |
|---|---|---|
| **Preprocessing** | fastp, FastQC | Trimmed FASTQ, QC reports |
| **Alignment** | Bowtie2, Samtools | Sorted BAM, mapping stats |
| **Post-Alignment** | Samtools (fixmate, markdup, view), deepTools (ATACshift) | Deduplicated, Tn5-shifted BAM |
| **QC Metrics** | Picard, Preseq, Qualimap, TSS enrichment, NSC/RSC cross-correlation | Fragment stats, library complexity, TSS, NSC/RSC |
| **QC Gate** | Custom Python parser | Pass/fail per sample (blocks downstream on failure) |
| **Peak Calling** | MACS2, IDR, ENCODE blacklist, Consensus peaks | Per-sample peaks, IDR peaks, consensus peaks |
| **Footprinting** | HINT-ATAC | Per-base TF footprints |
| **Motif Analysis** | HOMER, chromVAR | Enriched motifs, bias-corrected accessibility deviations |
| **Differential Accessibility** | DESeq2 | Volcano/MA/PCA plots, results table |
| **Visualization** | bedtools, deepTools, UCSC tools | BigWig tracks, heatmaps, correlation matrices |
| **Reporting** | MultiQC, benchmark aggregation | Unified HTML report, performance summary |

---

## ENCODE-Compliant QC Metrics

| Metric | Threshold (Human) | Threshold (Mouse) | Tool |
|---|---|---|---|
| TSS Enrichment | ≥ 7.0 | ≥ 4.0 | ATACseqQC (R) |
| FRiP Score | ≥ 0.2 | ≥ 0.15 | bedtools |
| NSC | ≥ 1.15 | ≥ 1.05 | phantompeakqualtools |
| RSC | ≥ 0.8 | ≥ 0.7 | phantompeakqualtools |
| Mapping Rate | ≥ 80% | ≥ 75% | samtools stats |
| Duplicate Rate | ≤ 20% | ≤ 25% | samtools markdup |
| Library Complexity | Preseq extrapolation | Preseq extrapolation | preseq |
| IDR Replicate Concordance | IDR ≤ 0.05 | IDR ≤ 0.05 | IDR |

---

## Configuration

### Single Source of Truth

All parameters live in `config.yaml`. No hardcoded values in rules.

```yaml
global:
  samples: "data/fastp/samples.tsv"
  references:
    genome_fa: "data/reference/genome.fa"
    bowtie2_index: "data/reference/index/genome"
    blacklist: "data/reference/ENCODE_blacklist.bed"
    annotation_gtf: "data/reference/annotation.gtf"
    motif_db: "data/motifs/jaspar_vertebrates.meme"

# Every tool block follows the same schema:
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

### Execution Profiles

| Profile | Use Case | Command |
|---|---|---|
| `profile/local` | Workstation (8 cores) | `snakemake --profile profile/local` |
| `profile/slurm` | HPC cluster (100 jobs) | `snakemake --profile profile/slurm` |
| `profile/test` | CI validation | `snakemake --profile profile/test --cores 4` |

---

## Repository Structure

```
├── Snakefile                    # Main entry point, lifecycle hooks
├── config.yaml                  # Single source of truth for all parameters
├── profile/                     # Execution profiles
│   ├── local/config.yaml        # Workstation (8 jobs)
│   ├── slurm/config.yaml        # HPC cluster (100 jobs)
│   └── test/config.yaml         # CI validation
├── rules/                       # 40+ modular rule definitions
│   ├── *.smk                    # Individual rule files
│   ├── envs/                    # Hierarchical conda environments
│   │   ├── 01_preprocessing/    # fastp, fastqc, multiqc
│   │   ├── 02_alignment/        # bowtie2
│   │   ├── 03_post_alignment/   # samtools, bedtools
│   │   ├── 04_metrics_qc/       # picard, preseq, qualimap, tss, cross_correlation
│   │   ├── 05_peak_calling/     # macs2, idr, homer, chromvar, footprinting, diff_accessibility
│   │   ├── 06_visualization/    # deeptools, bedgraphtobigwig
│   │   └── misc/                # template_tool
│   ├── scripts/                 # Custom R/Python analysis scripts
│   └── config/                  # MultiQC configuration
├── data/                        # Reference data and sample sheets
├── .github/workflows/           # CI/CD pipeline (lint + test)
└── assets/                      # Pipeline diagrams
```

---

## Comparison with Established Pipelines

| Feature | BDB-Genomics V2 | nf-core/atacseq | ENCODE |
|---|---|---|---|
| **QC execution gating** | ✅ Blocks downstream | ⚠️ Warns only | ⚠️ Manual |
| **Pre-flight validation** | ✅ Catches errors before DAG | ❌ Fails mid-run | ❌ |
| **Config-driven architecture** | ✅ 100% dynamic | ⚠️ Partial | ❌ Hardcoded |
| **IDR replicate concordance** | ✅ | ✅ | ✅ Required |
| **NSC/RSC cross-correlation** | ✅ | ✅ | ✅ Required |
| **Consensus peak calling** | ✅ | ✅ | ✅ |
| **Differential accessibility** | ✅ DESeq2 | ✅ DESeq2 | ✅ |
| **Footprinting** | ✅ HINT-ATAC | ✅ HINT-ATAC, TOBIAS | ✅ HINT-ATAC |
| **Motif bias correction** | ✅ chromVAR | ✅ chromVAR | ✅ |
| **Benchmark aggregation** | ✅ Built-in | ❌ | ❌ |
| **Setup complexity** | Edit 2 files | Learn DSL2 + Nextflow | Docker + complex configs |
| **scATAC-seq support** | ⚠️ Guide provided | ✅ Built-in | N/A |
| **Cloud deployment** | ❌ | ✅ AWS/GCP/Azure | ✅ |
| **Community** | Growing | 50+ contributors | ENCODE consortium |

---

## Usage

### Prerequisites

- Snakemake ≥ 8.0
- Conda or Mamba (recommended)
- Singularity/Apptainer (optional, for containerized execution)

### Execution

```bash
# Configure
# 1. Edit config.yaml
# 2. Populate data/fastp/samples.tsv

# Dry-run
snakemake -n --use-conda

# Execute
snakemake --use-conda --cores 32

# HPC (SLURM)
snakemake --profile profile/slurm

# Test mode (CI)
snakemake --profile profile/test --cores 4
```

### Adding a New Tool

1. Create `rules/your_tool.smk` (use `rules/template_tool.smk` as a guide)
2. Create `rules/envs/XX_category/your_tool.yaml`
3. Add `include: "rules/your_tool.smk"` to Snakefile
4. Add targets to the appropriate `*_TARGETS` list in Snakefile
5. Add config block to `config.yaml`

---

## Citation

Bhandary, H. (2026). *BDB-Genomics ATAC-seq Framework (Version 2.0.0)*. BDB-Genomics GitHub Repository. https://github.com/BDB-Genomics/atacseq-pipeline

## License

MIT License — see `LICENSE` file for details.
