# BDB-Genomics ATAC-seq Pipeline (V2.0.0)

A production-grade, modular Snakemake framework for end-to-end ATAC-seq analysis — from raw reads to differential accessibility. Engineered for reproducibility, scalability, and ENCODE-compliant quality control.

## Architectural Principles
- **Dynamic Reactivity**: Configuration-driven DAG architecture. All I/O paths and computational targets resolved at runtime via `config.yaml`.
- **Reproducibility**: Biocontainers (Singularity/Docker) + hierarchical Conda environments for consistent tool versioning.
- **Fail-Fast Validation**: Pre-flight validation (`validate_config.py`) audits config schema and sample metadata before DAG construction.
- **QC Gating**: Biological checkpoint system blocks downstream execution for failing samples.

## Pipeline Components

| Stage | Tools | Output |
|---|---|---|
| **Preprocessing** | fastp, FastQC | Trimmed FASTQ, QC reports |
| **Alignment** | Bowtie2, Samtools | Sorted BAM, mapping stats |
| **Post-Alignment** | Samtools (fixmate, markdup, view), deepTools (ATACshift) | Deduplicated, Tn5-shifted BAM |
| **QC Metrics** | Picard, Preseq, Qualimap, TSS enrichment (R), NSC/RSC cross-correlation | Fragment stats, library complexity, TSS score, NSC/RSC |
| **QC Gate** | Custom Python parser | Pass/fail per sample (FRiP, TSS, mapping, dup rate) |
| **Peak Calling** | MACS2, IDR, ENCODE blacklist | Per-sample peaks, IDR-filtered peaks, consensus peaks |
| **Differential Accessibility** | DESeq2 | Volcano plots, MA plots, PCA, heatmap, results table |
| **Visualization** | bedtools, deepTools, UCSC tools | BigWig tracks, heatmaps, correlation matrices |
| **Reporting** | MultiQC, benchmark aggregation | Unified HTML report, performance summary |

## ENCODE-Compliant QC Metrics

The pipeline implements all ENCODE ATAC-seq quality standards:

| Metric | Threshold | Tool |
|---|---|---|
| TSS Enrichment | ≥ 7.0 (human), ≥ 4.0 (mouse) | Custom R (ATACseqQC) |
| FRiP Score | ≥ 0.2 | bedtools |
| NSC (Normalized Strand Cross-Corr) | ≥ 1.15 | phantompeakqualtools |
| RSC (Relative Strand Cross-Corr) | ≥ 0.8 | phantompeakqualtools |
| Mapping Rate | ≥ 80% | samtools stats |
| Duplicate Rate | ≤ 20% | samtools markdup |
| Library Complexity | Preseq extrapolation | preseq |
| IDR Replicate Concordance | IDR ≤ 0.05 | IDR |

## Usage

### Prerequisites
- Snakemake ≥ 8.0
- Conda or Mamba (recommended)
- Singularity/Apptainer (optional, for containerized execution)

### Quick Start
```bash
# 1. Configure
# Edit config.yaml and data/fastp/samples.tsv

# 2. Dry-run
snakemake -n --use-conda

# 3. Execute
snakemake --use-conda --cores 32

# 4. HPC (SLURM)
snakemake --profile profile/slurm
```

### Test Mode
```bash
# Run with built-in test data (CI validation)
snakemake --profile profile/test --cores 4
```

## Repository Structure
```
├── Snakefile              # Main entry point, lifecycle hooks
├── config.yaml            # Single source of truth for all parameters
├── profile/               # Execution profiles (local, slurm, test)
├── rules/                 # 40+ modular rule definitions
│   ├── envs/              # Hierarchical conda environments
│   ├── scripts/           # Custom R/Python analysis scripts
│   └── config/            # MultiQC configuration
├── data/                  # Reference data and sample sheets
└── .github/workflows/     # CI/CD pipeline
```

## Comparison with Established Pipelines

| Feature | BDB-Genomics | nf-core/atacseq | ENCODE |
|---|---|---|---|
| IDR replicate concordance | ✅ | ✅ | ✅ Required |
| NSC/RSC cross-correlation | ✅ | ✅ | ✅ Required |
| Consensus peak calling | ✅ | ✅ | ✅ |
| Differential accessibility | ✅ | ✅ (DESeq2) | ✅ |
| QC execution gating | ✅ Blocks downstream | ⚠️ Warns only | ⚠️ Manual |
| Pre-flight validation | ✅ | ❌ | ❌ |
| Config-driven architecture | ✅ Fully dynamic | Partially | ❌ Hardcoded |
| Footprinting | ❌ | ✅ (HINT-ATAC) | ✅ |

## Citation
If you utilize this framework in your research, please cite:

Bhandary, H. (2026). *BDB-Genomics ATAC-seq Framework (Version 2.0.0)*. BDB-Genomics GitHub Repository. https://github.com/BDB-Genomics/atacseq-pipeline

## License
MIT License — see `LICENSE` file for details.
