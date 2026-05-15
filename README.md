<p align="center">
  <img src="assets/pipeline_diagram.svg" alt="Pipeline DAG" width="860" />
</p>

# BDB-Genomics ATAC-seq Pipeline (V1.1.0)

<p align="center">
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://github.com/BDB-Genomics/atacseq-pipeline/actions"><img src="https://img.shields.io/badge/Status-Production_Ready-brightgreen" alt="Status"></a>
  <a href="https://snakemake.readthedocs.io"><img src="https://img.shields.io/badge/Snakemake-≥7.0-brightgreen.svg" alt="Snakemake"></a>
</p>

> **Mentorship & Guidance**
> This pipeline was developed under the guidance of **Jessica Evangeline KC**, PhD Student, IBAB, Bangalore.

## Overview
A production-grade, modular, and containerized Snakemake workflow for paired-end ATAC-seq data. From raw reads to biological insights, every step is standardized for reproducibility and performance.

### ✨ Key Features
- **Dynamic Architecture**: Fully reactive DAG driven by `config.yaml`.
- **Global Containerization**: Integrated with **Biocontainers** (Singularity/Docker) for portable execution.
- **Smart Validation**: Proactive config & sample sheet validator with categorized hints.
- **Biological QC Gate**: Automated checkpoints for TSS Enrichment and FRiP metrics.
- **Advanced Reporting**: Custom MultiQC integration with PASS/FAIL/WARN status.

## 📁 Repository Layout
```text
Snakefile                 # Dynamic entry point with lifecycle hooks
config.yaml               # Central Source of Truth
data/                     # Input directory (FASTQs, References, Motifs)
rules/                    # Modularized Snakemake rules
rules/envs/               # Hierarchical Conda/Singularity definitions
rules/scripts/            # Advanced Python/R logic (Validation, QC, TSS)
assets/                   # Custom MultiQC configs and diagrams
```

## 🚀 Quick Start

1. **Configure**: Review `config.yaml` and populate `data/fastp/samples.tsv`.
2. **Validate**:
   ```bash
   snakemake -n
   ```
   *Our validator will guide you if any reference files or config keys are missing.*

3. **Execute**:
   ```bash
   snakemake --use-conda --use-singularity --cores 16
   ```

## 📊 Inputs
The workflow expects a Tab-Separated sample sheet at `data/fastp/samples.tsv`:
| sample | fastq_r1 | fastq_r2 | replicate | condition |
| :--- | :--- | :--- | :--- | :--- |
| WT_rep1 | path/r1.fq.gz | path/r2.fq.gz | 1 | WT |

## 🧬 QC Gate
The pipeline implements an automated gating system:
- **TSS Enrichment**: Validates signal-to-noise ratio at transcription start sites.
- **FRiP**: Fraction of Reads in Peaks validation.
- **Mapping & Duplication**: Ensures alignment quality meets research standards.
*Results are exported as JSON and aggregated in the final MultiQC report.*

## 📜 Citation
If you use this pipeline, please cite it as:
```text
Bhandary, H. (2026). BDB-Genomics ATAC-seq Framework (Version 1.1.0). GitHub. 
https://github.com/BDB-Genomics/atacseq-pipeline
```
*See [CITATION.cff](CITATION.cff) for more details.*

## ⚖️ License
Distributed under the **MIT License**. See `LICENSE` for more information.
