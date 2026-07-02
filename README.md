# BDB-Genomics ATAC-seq Framework

A production-grade, config-driven Snakemake framework for end-to-end chromatin accessibility analysis. Built for resilience, it supports both bulk and single-cell modalities, automatically scales from 4GB laptops to HPC clusters, and implements strict Quality Control gating to halt poor samples before downstream processing.

---

## 🏗️ Pipeline Architecture

```mermaid
graph TD
    %% ── Stage 1: Preprocessing ──
    Raw[Raw FASTQ Files] --> FastP[fastp<br>QC & Trimming]
    FastP --> FastQC[FastQC]

    %% ── Stage 2: Alignment & Processing ──
    FastP --> ModeSwitch{ATAC_MODE?}
    
    ModeSwitch -- bulk --> AlignTarget[Bowtie2<br>Target Alignment]
    ModeSwitch -- scatac --> AlignChromap[Chromap<br>Single-Cell Alignment]

    %% ── Stage 3: Filtering & QC ──
    AlignTarget --> FilterBulk[samtools MAPQ filter & Tn5 shift]
    AlignChromap --> FilterSC[ArchR Arrow creation & doublet removal]

    FilterBulk -.-> Picard[Picard Insert Metrics]
    FilterBulk -.-> Qualimap[Qualimap BamQC]
    FilterBulk -.-> TSS[TSS Enrichment]

    %% ── Stage 4: Peak Calling ──
    FilterBulk --> MACS2[MACS2 Peak Calling]
    MACS2 --> IDR[IDR Replicate Concordance]
    IDR --> Blacklist[Blacklist Filter]

    FilterSC --> PeakSC[ArchR Marker Peak Identification]

    %% ── Stage 5: Downstream Analysis ──
    Blacklist --> PeakAnnot[Peak Annotation<br>ChIPseeker]
    Blacklist --> Motif[Motif Analysis<br>HOMER]
    Blacklist --> DiffAcc[Differential Accessibility<br>DESeq2]
    
    FilterSC --> Cicero[Co-accessibility<br>Cicero]
    FilterSC --> chromVAR[Motif Accessibility<br>chromVAR]

    %% ── Stage 6: Footprinting ──
    FilterBulk --> TOBIAS[Footprinting<br>TOBIAS BINDetect]

    %% ── Styling ──
    classDef input fill:#f8f9fa,stroke:#6c757d,color:#000;
    classDef process fill:#e2e3e5,stroke:#383d41,color:#000;
    classDef analysis fill:#d1ecf1,stroke:#0c5460,color:#000;
    classDef diffbind fill:#e8daef,stroke:#6c3483,color:#1a1a2e;
    classDef qc fill:#fff3cd,stroke:#856404,color:#856404;

    class Raw input;
    class FastP,ModeSwitch,AlignTarget,AlignChromap,FilterBulk,FilterSC,MACS2,IDR,PeakSC,Cicero,chromVAR process;
    class Blacklist,PeakAnnot,Motif,TOBIAS analysis;
    class DiffAcc diffbind;
    class Picard,Qualimap,TSS,FastQC qc;
```

---

## ⚙️ Setup & Installation

Follow these steps to set up your environment, reference data, and metadata sheets.

### 1. Prerequisites & Environment Setup
The pipeline relies on **Snakemake 8.0+** and manages dependencies dynamically via Conda/Mamba environments. 

Install the base environment using Conda/Mamba:
```bash
# Create the environment with snakemake and yaml parser
mamba create -n snakemake -c conda-forge -c bioconda snakemake python=3.10 pyyaml

# Activate the environment
conda activate snakemake
```

### 2. Reference Data Preparation
All reference files must be placed inside the `data/reference/` directory (or configured explicitly in `config.yaml`). 

Your target Bowtie2 indices must be built beforehand:
```bash
# Example command to build target Bowtie2 index
bowtie2-build genome.fa data/reference/bowtie2/genome
```

Ensure your directory structure matches the following tree:
```text
data/
├── reference/
│   ├── genome.fa                    # Target reference genome FASTA
│   ├── genome.chrom.sizes           # Chromosome sizes file (generated via: samtools faidx)
│   ├── annotation.gtf               # GTF/GFF gene annotation
│   ├── ENCODE_blacklist.bed         # Bed file of blacklisted regions to exclude
│   └── bowtie2/
│       ├── genome.1.bt2             # Bowtie2 index files for target genome
│       └── ...
└── samples.tsv                      # Tab-delimited sample sheet metadata
```

### 3. Metadata & Configuration
* **Sample Sheet (`data/samples.tsv`)**: Create a tab-separated file with these exact headers. Specify sample names, replicates, experimental conditions, and path locations for your raw paired-end reads:
  ```text
  sample	replicate	condition	fastq_r1	fastq_r2
  sample_1	1	control	data/reads/sample_1_R1.fq.gz	data/reads/sample_1_R2.fq.gz
  sample_2	2	control	data/reads/sample_2_R1.fq.gz	data/reads/sample_2_R2.fq.gz
  ```
* **Pipeline Config (`config.yaml`)**: Edit the global parameters, adapter trimming settings, filtering thresholds (e.g. MAPQ scores, TSS limits), and target file pathways to align with your organism of interest.

### 4. Setup Verification
Run the built-in validation script to ensure all referenced config keys, types, and physical paths on disk are syntactically and structurally correct before launching the pipeline:
```bash
python3 rules/scripts/validate_config.py config.yaml
```

---

## 🚀 Running the Pipeline

### Option A: Standard Cluster / Server Run
Run Snakemake directly, enabling it to download and manage the required tool dependencies automatically inside Conda environments:
```bash
# Bulk ATAC run
snakemake --cores 8 --use-conda

# Single-cell ATAC run
ATAC_MODE=scatac snakemake --cores 8 --use-conda
```

### Option B: Low-Resource Batch Execution (≤4GB RAM machines)
For local testing or execution on standard personal laptops where parallel Snakemake jobs cause memory/OOM crashes, use the cohort batch orchestrator:
```bash
python3 rules/scripts/run_batched.py --batch-size 2 --cores 4 --memory 4000
```

---

## 🔒 Security & Robustness Features

| Layer | Mechanism |
|---|---|
| **Pre-flight validation** | `validate_config.py` checks all config keys, scalar types, and physical file paths before DAG construction |
| **Sample sanitization** | Regex rejects shell metacharacters and `..` path traversal in sample names |
| **Shell safety** | Every rule uses `set -euo pipefail`; Python subprocesses use `shell=False` |
| **Graceful degradation** | R/Python analytics write placeholder outputs on zero-data scenarios instead of crashing |
| **Type safety** | Config path extractor rejects boolean/None coercion into file paths |
| **Reproducibility** | Pinned Conda environments + Singularity container directives on every rule |

---

## 🏗️ Repository Structure

```text
BDB-Genomics/atacseq-pipeline/
├── .github/workflows/          # CI/CD configuration (lint.yml)
├── assets/                     # Banners, logos, visual assets
├── profile/
│   ├── local/                  # Local execution profile
│   ├── slurm/                  # SLURM cluster profile
│   ├── low_resource/           # ≤4GB RAM laptop profile
│   ├── test/                   # CI test profile (relaxed QC)
│   ├── aws/                    # AWS Batch + Tibanna profile
│   ├── gcp/                    # Google Life Sciences profile
│   ├── azure/                  # Azure Batch profile
│   └── kubernetes/             # Kubernetes cluster profile
├── rules/
│   ├── scripts/
│   │   ├── README.md                   # Flowcharts and script reference
│   │   ├── aggregate_logs.py           # Structured JSON telemetry
│   │   ├── atacseq_tool.py             # LangChain agent wrapper
│   │   ├── geo_agent_bridge.py         # GEOAgent metadata importer
│   │   ├── validate_config.py          # Pre-flight validation
│   │   ├── test_validate_config.py     # Pytest suite
│   │   ├── generate_test_data.py       # Synthetic CI data generator
│   │   ├── run_batched.py              # Low-memory batch executor
│   │   └── [*.R]                       # R analysis scripts (ArchR, DESeq2, etc.)
│   ├── envs/                   # Conda environment definitions
│   └── [40+ .smk files]        # Snakemake rules
├── config.yaml                 # Configuration file
├── Snakefile                   # Snakemake entry point
└── AGENTS.md                   # Agent entrypoint and navigation map
```
