# BDB-Genomics ATAC-seq Pipeline

A production-grade, config-driven Snakemake framework for end-to-end ATAC-seq analysis. Built for resilience, it supports both bulk and single-cell modalities, automatically scales from 4GB laptops to HPC clusters, and implements strict Quality Control gating to halt poor samples before downstream processing.

[![CI](https://github.com/BDB-Genomics/atacseq-pipeline/actions/workflows/lint.yml/badge.svg)](https://github.com/BDB-Genomics/atacseq-pipeline/actions/workflows/lint.yml)
[![Snakemake](https://img.shields.io/badge/Snakemake-%E2%89%A58.0-blue.svg)](https://snakemake.github.io)

---

## 1. Quick Start

### Installation & Execution (Local)
The pipeline handles all tool dependencies internally via Conda and Singularity.
```bash
conda create -n atacseq snakemake>=8.0 -c conda-forge -c bioconda
conda activate atacseq

# Standard Bulk run (8 cores)
snakemake --use-conda --cores 8

# Single-cell ATAC run
ATAC_MODE=scatac snakemake --use-conda --cores 8
```

### Installation & Execution (Docker Container)
For platforms where Conda/Singularity installation is difficult (e.g. macOS or Windows), you can run the pipeline directly inside a Docker container.

#### 1. Build the Host Runner Image:
```bash
docker build -t bdb-atacseq .
```
*Note: The Dockerfile creates a host environment (using micromamba) containing Snakemake and Python. Individual rule dependencies (like Bowtie2, MACS2) will still be downloaded dynamically by Snakemake at runtime.*

#### 2. Execute the Pipeline via Docker:
Run the pipeline by mounting your workspace directory into the container:
```bash
docker run -it --rm \
  -v $(pwd):/app \
  -v /var/run/docker.sock:/var/run/docker.sock \
  bdb-atacseq --use-conda --cores 8
```
*(Optional: If running in a Docker-in-Docker environment, mounting the docker socket allows Snakemake to spin up tool containers from inside the host runner).*

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

### Profiles & Environments
The framework supports 8 pre-configured profiles under the `profile/` directory. These profiles adjust max jobs, print shell commands, configure executors, and set default resource footprints:

*   **`local`**: Sets Snakemake to run up to 8 concurrent local jobs.
*   **`slurm`**: Submits rules directly to a cluster workload manager using customized rule-resource mappings.
*   **`low_resource`**: Forces rule execution boundaries (e.g., caps every rule to a maximum of 4GB memory limits) for local execution on standard laptops.
*   **`test`**: Pre-configured CI test profile. Uses a relaxed configuration file (`config_test.yaml`) to allow minimal synthetic testing datasets to bypass strict QC enrichment thresholds.
*   **`aws`**: Configured to run on Amazon Web Services using AWS Batch, S3 buckets, and the `tibanna` executor.
*   **`gcp`**: Configured to run on Google Cloud Platform utilizing `google-lifesciences` executors and Google Cloud Storage (GCS) buckets.
*   **`azure`**: Configured for Azure Batch execution and Blob storage integration.
*   **`kubernetes`**: Container-native execution scaling across a Kubernetes cluster.

### Ultra-Low Memory Sequential Batching
For massive sample datasets on limited-resource systems, run the custom batch execution manager:
```bash
python3 rules/scripts/run_batched.py --batch-size 2 --cores 8 --profile profile/local
```
This processes samples in batches of 2 sequentially, avoiding parallel execution memory peaks while utilizing all available cores per rule.

---

## 3. Pipeline Architecture

Switching the `ATAC_MODE` environment variable dictates which modality analysis track is executed:

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

## 5. Structured Logging & Auditing

The pipeline records structured JSON metrics for downstream AI analysis or automated run reports. On completion or execution failure, Snakemake executes the log parser (`rules/scripts/aggregate_logs.py`) which generates `results/reporting/pipeline_execution_summary.json`.

*   **On Success**: Consolidates resource benchmarks (CPU time, peak memory usage, and execution status) for every Snakemake rule in the DAG.
*   **On Failure**: Recursively crawls the `logs/` directory to locate error sources, uses regular expression filters to avoid false positives (e.g., matching "0 errors" or "no exceptions"), and extracts the last 5 relevant error lines to provide a clean execution failure trace.

---

## 6. Testing & CI Sandboxes

The repository contains two utilities for pipeline testing, benchmarking, and development:

### A. Synthetic CI Data Generator
Generate minimal but completely valid synthetic datasets for CI validation:
```bash
python3 rules/scripts/generate_test_data.py
```
This outputs synthetic FASTQ, FASTA genome references, GTF annotation files, and Bowtie indices. Reads are intentionally mapped and distributed near target TSS sites to guarantee that Bioconductor metrics (like `tss_enrichment.R` and `diff_accessibility.R`) pass without encountering division-by-zero or length mismatch exceptions.

### B. ENCODE Real-Data Sandbox
To test the pipeline against real-world biological samples, set up the hg38 sandbox environment:
```bash
bash rules/scripts/download_real_data.sh
```
This script downloads a subsampled ENCODE ChIP/ATAC sample (ENCSR356KRQ), UCSC references for chromosomes 19 and M, GENCODE v44 basic annotations, and JASPAR motif libraries, then builds Bowtie2 and Chromap index files automatically.

---

## 7. Output Manifest

All outputs are written to the `results/` directory, cleanly organized by stage:

* **`results/alignment/`**: Post-filtered, sorted, and Tn5-shifted BAMs.
* **`results/metrics_qc/`**: MultiQC HTML report aggregating FastQC, Preseq, Picard, and the QC Gate JSONs.
* **`results/peak_calling/`**: MACS2 narrowPeaks, consensus BEDs, and IDR sets.
* **`results/differential/`**: DESeq2 tables, Volcano/MA/PCA plots.
* **`results/footprinting/`**: TOBIAS bias-corrected BigWigs and BINDetect motif plots.
* **`benchmarks/`**: Memory and CPU time consumption for every single job executed.

---

## 8. Agentic & GEOAgent Integration

The pipeline is fully integrated into autonomous agentic ecosystems (such as Stanford's Biomni, CoScientist, or GEOAgent) as a downstream execution engine.

### JiekaiLab/GEOAgent Metadata Bridge
If you discover and retrieve dataset metadata packages from the Gene Expression Omnibus (GEO) via the **GEOAgent** portal, you can convert its standardized metadata files (e.g. `ATAC_meta.csv`) directly into a BDB-Genomics execution config.

Run the metadata bridge script:
```bash
python3 rules/scripts/geo_agent_bridge.py path/to/GEOAgent_ATAC_meta.csv --download
```
* **Parameters:**
  * `--download`: Automatically fetches raw SRA runs from SRA-AWS links or NCBI via `prefetch` / SRA Toolkit and unpacks them to `data/fastq/`.
  * `--out-samples`: Path to write the output BDB sample sheet (defaults to `data/fastp/samples_geo.tsv`).
  * `--out-config`: Path to write the configured pipeline file (defaults to `config_geo.yaml`).

### Agentic Tool Wrapper (LangChain)
The pipeline is wrapped as a LangChain-compatible tool node in `rules/scripts/atacseq_tool.py` for direct registration in LLM agent toolkits:

```python
from rules.scripts.atacseq_tool import run_atacseq_pipeline

# Trigger end-to-end GEO processing and pipeline run autonomously:
status = run_atacseq_pipeline(
    geo_metadata_csv="path/to/GEOAgent_ATAC_meta.csv",
    download_geo=True,
    profile="local",
    cores=8
)
print(status)
```

The tool handles pre-flight configuration validations and returns execution metrics alongside structured JSON execution summaries (generated on run success/failure) directly to the LLM context.

---

## 9. Depositing to Zenodo (Publishing & Archiving)

To make your analyses and code citable in scientific publications, you can deposit this framework to Zenodo to obtain a persistent Digital Object Identifier (DOI).

### Option A: Direct Zenodo CLI Tool
The repository includes a dedicated helper script (`rules/scripts/zenodo_deposit.py`) to build a clean software release (via `git archive` to exclude massive sample files or logs) and draft a Zenodo deposition.

1. **Generate a Zenodo Access Token**:
   * For testing, create a token at [Zenodo Sandbox](https://sandbox.zenodo.org/account/settings/applications/).
   * For production, create a token at [Zenodo Production](https://zenodo.org/account/settings/applications/).
   * Ensure your token has `deposit:write` and `deposit:actions` scopes.

2. **Run the Deposition CLI**:
   ```bash
   # Upload a draft to Zenodo Sandbox (Safe test):
   export ZENODO_TOKEN="your_sandbox_token_here"
   python3 rules/scripts/zenodo_deposit.py
   
   # Upload a draft to Production Zenodo:
   export ZENODO_TOKEN="your_production_token_here"
   python3 rules/scripts/zenodo_deposit.py --production
   ```
*Note: The script automatically parses your name, title, version, keywords, abstract, and licensing directly from `CITATION.cff`.*

### Option B: Native GitHub-Zenodo Integration (Automated)
For public repositories hosted on GitHub:
1. Log in to [Zenodo](https://zenodo.org/) using your GitHub credentials.
2. Go to your Zenodo Profile -> GitHub settings and toggle the switch for `BDB-Genomics/atacseq-pipeline` to **On**.
3. Create a new GitHub Release on your repository.
4. Zenodo will automatically capture the repository release archive, mint a new DOI, and link it to your profile page.

---
**Citation:** Bhandary, H. (2026). *BDB-Genomics ATAC-seq Framework (Version 3.0.0).*


