# BDB-Genomics ATAC-seq Pipeline

A production-grade, modular Snakemake pipeline for reproducible ATAC-seq analysis, featuring upfront configuration validation, robust Quality Control (QC) gating, and automatic hardware resource profiling.

![Pipeline Architecture](pipeline_architecture.png)

---

## Core Capabilities

The pipeline implements industry gold-standard practices to eliminate common failure points in high-throughput genomics:

* **Upfront Pre-Flight Validation**: Prevents mid-run crashes by validating configuration parameters, input sample sheets, and raw file paths before starting any job execution.
* **Unified Quality Control Gate**: Dynamically blocks low-quality samples from running expensive downstream rules (such as footprinting or differential analysis) based on custom TSS, FRiP, duplication, and mapping thresholds.
* **Resilient Rule Fallbacks**: Downstream annotation, motif analysis, and visualization rules natively handle zero-peak or low-coverage samples. Scripts catch statistical failures and generate valid placeholder outputs to avoid stopping the entire pipeline DAG.
* **Immutable Containerization**: Built-in support for Galaxy Project Singularity containers via `--use-singularity` ensures fully reproducible, OS-independent pipeline runs.
* **Dual Modality Support**: Seamlessly toggles between bulk ATAC-seq and single-cell ATAC-seq using a single command or configuration key.

---

## Quick Start

### 1. Installation
Create and activate the environment with Snakemake and Conda:
```bash
conda create -n atacseq snakemake>=8.0 mamba -c conda-forge -c bioconda
conda activate atacseq
```

### 2. Configuration
Configure the execution by editing two files:
* **`config.yaml`**: Contains global reference paths, biological QC thresholds, and rule resource limits.
* **`data/fastp/samples.tsv`**: Sample sheet specifying sample names, FASTQ file paths, replicates, and experimental conditions.

### 3. Execution
Run the default bulk ATAC-seq pipeline:
```bash
snakemake --use-conda --cores 8
```

To run single-cell ATAC-seq mode, set the environment variable:
```bash
ATAC_MODE=scatac snakemake --use-conda --cores 8
```

---

## Modality Selection

Toggling modes adjusts the tools and analytical steps automatically:

| Process | Bulk ATAC-seq Mode | Single-cell ATAC-seq Mode |
| :--- | :--- | :--- |
| **Alignment** | Bowtie2 | Chromap (preset: atac) |
| **Post-Processing** | Samtools (sort, deduplicate, filter, Tn5 shift) | ArchR (Arrow files, doublet filtering) |
| **Peak Calling** | MACS2 + IDR (Replicate Concordance) | ArchR Clustering + Marker Peaks |
| **Co-accessibility** | Not Applicable | Cicero (CCAN networks) |
| **Differential Analysis** | DESeq2 | ArchR Per-Cluster Marker Genes |
| **Footprinting** | HINT-ATAC + TOBIAS | chromVAR (Motif Accessibility Deviations) |
| **QC Gates** | TSS Enrichment, FRiP, Mapping Rate, Duplicates | TSS Enrichment, Fragments per Cell, Doublet Rate |

---

## Hardware Execution Profiles

Select the profile that fits your computational resources:

| Profile | Target Environment | Memory (RAM) | Parallel Jobs | Command |
| :--- | :--- | :--- | :--- | :--- |
| `profile/local` | Workstation | 16 GB | 8 | `snakemake --profile profile/local` |
| `profile/low_resource` | Laptop | 8 GB | 2 | `snakemake --profile profile/low_resource` |
| `profile/slurm` | HPC Cluster | Custom | 100 | `snakemake --profile profile/slurm` |
| `profile/test` | CI/CD Runner | 7 GB | 4 | `snakemake --profile profile/test` |

### Memory-Capped Sequential Batching
For machines with less than 4 GB of RAM, execute samples sequentially to bypass simultaneous memory peaks:
```bash
python3 rules/scripts/run_batched.py --batch-size 1 --cores 2 --memory 4000
```
This wrapper script processes one batch of samples through the pipeline, caches the intermediate results, and runs final MultiQC aggregation at the end.

---

## Configuration Reference

Key execution parameters are configured in the `config.yaml` file:

```yaml
global:
  mode: "bulk"  # Analysis mode: bulk or scatac
  samples: "data/fastp/samples.tsv"
  references:
    genome_fa: "data/reference/genome.fa"
    bowtie2_index: "data/reference/index/genome"
    blacklist: "data/reference/ENCODE_blacklist.bed"
    annotation_gtf: "data/reference/annotation.gtf"
    motif_db: "data/motifs/jaspar_vertebrates.meme"

qc_gate:
  params:
    min_frip: 0.2
    min_tss_enr: 7.0
    min_mapping_rate: 80.0
    max_duplicate_rate: 20.0
```

---

## Outputs Generated

Upon completion, output files are organized under the `results/` directory:

* **Quality Control**: FastQC reports, TSS enrichment profiles, Cross-Correlation metrics (NSC/RSC), library complexity estimates (Preseq), and a consolidated MultiQC HTML report.
* **Alignment**: Coordinate-sorted, deduplicated, and blacklist-filtered BAM files.
* **Peak Calling**: MACS2 narrowPeaks, IDR-filtered consensus peak sets, and annotated peak tables.
* **Footprinting**: HINT-ATAC footprint BED files, TOBIAS footprint BigWigs, and differential binding sites (TOBIAS BINDetect).
* **Differential Accessibility**: DESeq2 tables, Volcano plots, MA plots, PCA plots, and sample correlation heatmaps.

---

## Extending the Pipeline

To add a new tool or execution rule:
1. Create a Snakemake rule file in `rules/your_tool.smk`.
2. Define the rule dependencies in a conda configuration at `rules/envs/your_tool.yaml`.
3. Include the rule file in the root `Snakefile`:
   ```python
   include: "rules/your_tool.smk"
   ```
4. Define the target outputs inside `Snakefile` or `config.yaml`.

---

## Citation

If you use this pipeline in your research, please cite:
Bhandary, H. (2026). *BDB-Genomics ATAC-seq Framework (Version 2.1.0)*. GitHub Repository. https://github.com/BDB-Genomics/atacseq-pipeline

---

## License

This project is licensed under the MIT License - see the `LICENSE` file for details.
