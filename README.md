# BDB-Genomics ATAC-seq Pipeline

A production-grade Snakemake framework for end-to-end ATAC-seq analysis. Supports both bulk and single-cell modalities from a single codebase, with built-in quality control gating that blocks low-quality samples before they consume downstream compute.

[![CI](https://github.com/BDB-Genomics/atacseq-pipeline/actions/workflows/lint.yml/badge.svg)](https://github.com/BDB-Genomics/atacseq-pipeline/actions/workflows/lint.yml)
[![Snakemake](https://img.shields.io/badge/Snakemake-%E2%89%A58.0-blue.svg)](https://snakemake.github.io)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## Table of Contents

1. [Design Principles](#design-principles)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Running the Pipeline](#running-the-pipeline)
5. [Execution Profiles](#execution-profiles)
6. [Bulk and Single-Cell Modes](#bulk-and-single-cell-modes)
7. [Pipeline Stages](#pipeline-stages)
8. [Quality Control Gate](#quality-control-gate)
9. [Low-Resource Execution](#low-resource-execution)
10. [Continuous Integration](#continuous-integration)
11. [Extending the Pipeline](#extending-the-pipeline)
12. [Repository Structure](#repository-structure)
13. [Citation](#citation)

---

## Design Principles

**Pre-flight validation.** Before Snakemake builds the DAG, `validate_config.py` parses `config.yaml` and the sample sheet. It verifies that every referenced file path exists on disk, that sample names match the pattern `[A-Za-z0-9._-]+`, and that every rule block contains the required `input`, `output`, `params`, `threads`, and `resources` keys. Errors are categorized (Reference Files, Sample Sheet, Schema/Keys, Parameters) and printed with filesystem hints. The pipeline exits before any job is scheduled.

**Quality control gating.** After alignment metrics are collected, `parse_qc_metrics.py` evaluates each sample against four thresholds: FRiP, TSS enrichment, mapping rate, and duplication rate. Samples that fail any threshold produce a `FAILED` status in their `_qc_pass.txt` file and are blocked from peak calling, footprinting, and differential analysis. The pipeline does not stop; it continues processing passing samples and produces a complete MultiQC report that flags failures.

**Config-driven architecture.** Every tool parameter, file path, resource limit, and biological threshold is declared in `config.yaml`. The 47 Snakemake rule files are stateless wrappers that read from this config at runtime. YAML anchors (`&GENOME_FA` / `*GENOME_FA`) ensure that a reference path defined once propagates to every rule that needs it. Changing from hg38 to mm10 means editing one line.

**Resilient fallbacks.** Rules that operate on peak files (ChIPseeker, HOMER, TOBIAS, deepTools heatmaps, chromVAR, HINT-ATAC) check whether the input peak file is empty before executing the main tool. If it is, they write structurally valid placeholder outputs (empty DataFrames with correct headers, dummy BigWig files with valid chromosome headers, placeholder PDFs) and exit cleanly. The DAG never crashes from a zero-peak sample.

**Containerization.** Every rule declares both a `conda:` environment file and a `container:` URL pointing to a Galaxy Project Singularity image. Running with `--use-singularity` produces bit-identical results across operating systems without relying on Conda dependency resolution.

---

## Installation

```bash
conda create -n atacseq snakemake>=8.0 -c conda-forge -c bioconda
conda activate atacseq
```

Per-rule Conda environments are defined under `rules/envs/` and created automatically on first run. No manual tool installation is needed.

---

## Configuration

Two files control the pipeline:

### Sample sheet (`data/fastp/samples.tsv`)

Tab-separated, one row per sample:

```
sample    fastq_r1                              fastq_r2                              replicate    condition
patient1  data/fastq/patient1_R1.fastq.gz       data/fastq/patient1_R2.fastq.gz       1            treated
patient2  data/fastq/patient2_R1.fastq.gz       data/fastq/patient2_R2.fastq.gz       2            treated
ctrl1     data/fastq/ctrl1_R1.fastq.gz          data/fastq/ctrl1_R2.fastq.gz          1            control
ctrl2     data/fastq/ctrl2_R1.fastq.gz          data/fastq/ctrl2_R2.fastq.gz          2            control
```

The `condition` column drives DESeq2 differential analysis and TOBIAS BINDetect differential binding. The `replicate` column drives IDR analysis -- the pipeline automatically generates all pairwise replicate comparisons per condition using `itertools.combinations`.

### Pipeline configuration (`config.yaml`)

Every tool block follows a uniform schema:

```yaml
global:
  mode: "bulk"                                         # "bulk" or "scatac"
  samples: "data/fastp/samples.tsv"
  references:
    genome_fa: &GENOME_FA "data/reference/genome.fa"
    genome_sizes: &GENOME_SIZES "data/reference/genome.chrom.sizes"
    bowtie2_index: &BOWTIE2_INDEX "data/reference/index/genome"
    blacklist: &BLACKLIST "data/reference/ENCODE_blacklist.bed"
    annotation_gtf: &ANNOTATION_GTF "data/reference/annotation.gtf"
    motif_db: &MOTIF_DB "data/motifs/jaspar_vertebrates.meme"

bowtie2:
  input: "results/preprocessing/fastp"
  output: "results/alignment/bowtie2"
  params:
    index: *BOWTIE2_INDEX
    sensitive: "--very-sensitive"
  threads: 8
  resources:
    mem_mb: 16000
    time: 240                          # integer minutes (Snakemake 8 requirement)
```

The MACS2 rule dynamically computes genome size by summing the `genome.chrom.sizes` file at parse time, so no hardcoded genome size string is needed:

```python
# From rules/macs2_peak_calling.smk
params:
    gsize=sum(int(line.strip().split()[1]) for line in open(config['global']['references']['genome_sizes']))
```

---

## Running the Pipeline

```bash
# Full bulk ATAC-seq run
snakemake --use-conda --cores 8

# Dry run (print the DAG without executing)
snakemake -n --use-conda --cores 8

# Resume after a failure (skip completed outputs)
snakemake --use-conda --cores 8 --rerun-incomplete

# Reproducible run with Singularity containers
snakemake --use-singularity --cores 8
```

On startup, the Snakefile prints the detected mode and sample count:

```
[START] BDB-Genomics ATAC-seq Framework
Mode: BULK
Samples: 3 samples detected
```

---

## Execution Profiles

| Profile | Target hardware | Parallel jobs | Command |
| :--- | :--- | ---: | :--- |
| `local` | Workstation (16+ GB, 8+ cores) | 8 | `snakemake --profile profile/local` |
| `low_resource` | Laptop (4-8 GB, 2-4 cores) | 2 | `snakemake --profile profile/low_resource` |
| `slurm` | HPC cluster (SLURM scheduler) | 100 | `snakemake --profile profile/slurm` |
| `test` | GitHub Actions CI runner | 4 | `snakemake --profile profile/test` |

Each profile is a directory under `profile/` containing a Snakemake `config.yaml` with bundled flags. Example for SLURM:

```yaml
# profile/slurm/config.yaml
executor: slurm
use-conda: true
jobs: 100
restart-times: 1
latency-wait: 60
default-resources:
  mem_mb: 4000
  time: 60
  slurm_partition: "standard"
  slurm_account: "bdb_genomics"
```

---

## Bulk and Single-Cell Modes

```bash
# Bulk ATAC-seq (default)
snakemake --use-conda --cores 8

# Single-cell ATAC-seq
ATAC_MODE=scatac snakemake --use-conda --cores 8
```

The mode switch controls which rule files the Snakefile loads via `include:` directives:

| Stage | Bulk mode | Single-cell mode |
| :--- | :--- | :--- |
| Alignment | Bowtie2 (`--very-sensitive`, piped to `samtools view -Sb`) | Chromap (`--preset atac`) |
| Post-alignment | Samtools sort, fixmate, markdup, MAPQ filter (q30, -F 3844, -f 2), blacklist removal (bedtools intersect -v), Tn5 shift (deepTools `alignmentSieve --ATACshift`) | ArchR: Arrow file creation, doublet detection (threshold 0.2), iterative LSI clustering (resolution 0.8, dims 1:30) |
| Peak calling | MACS2 (`callpeak -f BAMPE --nomodel -q 0.01`), IDR replicate concordance (threshold 0.05) | ArchR marker peak identification |
| Co-accessibility | -- | Cicero (window 500 bp, distance cutoff 250 kb) |
| Differential | DESeq2 (FDR 0.05, log2FC 1.0) with volcano, MA, PCA, and heatmap plots | ArchR per-cluster markers |
| Footprinting | HINT-ATAC (`rgt-hint footprinting --atac-seq --paired-end`) + TOBIAS (ATACorrect, FootprintScores, BINDetect) | chromVAR motif accessibility deviations |

---

## Pipeline Stages

The bulk mode DAG is organized into eight sequential stages. For a 3-sample experiment, this produces 119 jobs.

### 1. Preprocessing

fastp trims adapters (auto-detected for PE), clips 5 bp from both read fronts, and enforces a minimum read length of 30 bp. FastQC generates per-base quality reports on the trimmed reads.

### 2. Alignment

Bowtie2 aligns trimmed paired-end reads in `--very-sensitive` mode. Output is piped directly through `samtools view -Sb` to produce a BAM file without an intermediate SAM.

### 3. Post-alignment filtering

Seven sequential operations clean each BAM:

1. **Coordinate sort** (samtools sort)
2. **Mitochondrial read quantification** (count reads on chrM/chrMT)
3. **Mate pair correction** (samtools fixmate)
4. **Duplicate marking** (samtools markdup)
5. **Quality and flag filtering** (samtools view: MAPQ >= 30, exclude flags 3844, require proper pairs with -f 2)
6. **Blacklist removal** (bedtools intersect -v against ENCODE blacklist BED)
7. **Tn5 transposase shift** (deepTools alignmentSieve --ATACshift: +4/-5 bp offset)

### 4. Quality metrics

Nine tools collect ENCODE-compliant metrics per sample:

| Tool | Metric |
| :--- | :--- |
| Samtools stats | Post-filtering alignment statistics |
| Picard CollectAlignmentSummaryMetrics | Mapping rate, mismatch rate |
| Picard CollectInsertSizeMetrics | Fragment size distribution |
| Fragment size analysis (R) | Nucleosomal periodicity assessment |
| TSS enrichment (R, ATACseqQC) | Signal-to-noise at transcription start sites (2 kb window) |
| Phantompeakqualtools (run_spp.R) | NSC and RSC cross-correlation scores |
| Preseq | Library complexity extrapolation curve |
| Qualimap BamQC | Genome coverage distribution, GC bias |
| FRiP (bedtools + samtools) | Fraction of read-1 fragments overlapping peaks |

### 5. QC gate

See [Quality Control Gate](#quality-control-gate).

### 6. Peak calling and downstream analysis

| Tool | What it produces |
| :--- | :--- |
| MACS2 | Per-sample narrowPeak files (BAMPE mode, no model, q-value 0.01) |
| Blacklist filter | Peaks with ENCODE blacklist regions removed |
| IDR | Replicate-concordant peaks per condition (threshold 0.05, ranked by score) |
| Consensus peaks | Merged peak set: `bedtools merge -d 100`, retained if present in >= 2 samples |
| Peak count matrix | Per-sample read counts in consensus peak regions (for DESeq2 input) |
| ChIPseeker (R) | Genomic feature annotation (promoter, exon, intron, intergenic) using `makeTxDbFromGFF` |
| HOMER | De novo and known motif enrichment (`findMotifsGenome.pl`, motif lengths 8/10/12, window 200 bp) |
| DESeq2 (R) | Differentially accessible regions, volcano plot, MA plot, PCA, heatmap |
| HINT-ATAC (RGT) | Per-base TF footprint positions from paired-end ATAC-seq signal |
| TOBIAS ATACorrect | Tn5 bias-corrected signal BigWig tracks |
| TOBIAS FootprintScores | Footprint score BigWig tracks |
| TOBIAS BINDetect | Differential TF binding between conditions using motif database |
| chromVAR (R) | Bias-corrected motif accessibility deviation scores per sample |

### 7. Visualization

| Tool | Output |
| :--- | :--- |
| bedtools genomecov + bedGraphToBigWig | Signal BigWig tracks for genome browsers |
| deepTools bamCoverage | CPM-normalized coverage BigWig tracks |
| deepTools computeMatrix + plotHeatmap | Signal heatmaps centered on peak summits (3 kb upstream/downstream) |
| deepTools multiBigwigSummary + plotCorrelation | Pearson correlation heatmap across all samples (1 kb bins) |

### 8. Reporting

MultiQC aggregates outputs from FastQC, fastp, samtools stats, Picard, Preseq, Qualimap, and the QC gate JSON files into a single interactive HTML report. A benchmark summary TSV records runtime (seconds), peak memory (MB), and CPU usage for every rule execution.

---

## Quality Control Gate

The gate evaluates four metrics per sample using `parse_qc_metrics.py`:

| Metric | Default | Source file |
| :--- | ---: | :--- |
| FRiP score | >= 0.2 | `{sample}_frip.txt` |
| TSS enrichment | >= 7.0 | `{sample}_tss_enrichment.txt` |
| Mapping rate | >= 80.0% | `{sample}_postFiltering.stats.txt` |
| Duplicate rate | <= 20.0% | `{sample}_postFiltering.stats.txt` |

Outputs per sample: `{sample}_qc_pass.txt` (human-readable) and `{sample}_qc_pass.json` (machine-readable, consumed by MultiQC).

To adjust thresholds:

```yaml
qc_gate:
  params:
    min_frip: 0.15           # relax for low-depth pilot data
    min_tss_enr: 5.0         # relax for non-standard organisms
    min_mapping_rate: 70.0
    max_duplicate_rate: 30.0
```

The test profile (`profile/test/config_test.yaml`) overrides all thresholds to fully permissive values (0.0 / 0.0 / 0.0 / 100.0) so that synthetic CI data passes the gate unconditionally.

---

## Low-Resource Execution

### Low-resource profile

The `low_resource` profile caps every rule individually. It runs a maximum of 2 parallel jobs:

```bash
snakemake --profile profile/low_resource
```

Per-rule memory caps (excerpt from `profile/low_resource/config.yaml`):

| Rule | Memory | Threads |
| :--- | ---: | ---: |
| `bowtie2_align` | 4 GB | 2 |
| `samtools_markdup` | 4 GB | 2 |
| `macs2_peak_calling` | 4 GB | 2 |
| `tobias_atacorrect` | 4 GB | 2 |
| `differential_accessibility` | 4 GB | 2 |
| `samtools_index` | 1 GB | 1 |
| `multiqc` | 2 GB | 1 |

All 40+ rules have explicit caps. The default fallback for unlisted rules is 2 GB / 1 thread.

### Sequential batching

For machines with less than 4 GB RAM, `run_batched.py` processes samples one at a time:

```bash
python3 rules/scripts/run_batched.py --batch-size 1 --cores 2 --memory 4000
```

The script reads the sample sheet, partitions samples into batches, and invokes Snakemake once per batch. All batches write to the same `results/` directory, so Snakemake skips completed outputs automatically. After all per-sample batches finish, a final invocation runs MultiQC aggregation.

```bash
# Preview batch assignments without executing
python3 rules/scripts/run_batched.py --batch-size 1 --dry-run

# Process 2 samples per batch with extra Snakemake flags
python3 rules/scripts/run_batched.py --batch-size 2 --cores 4 --memory 8000 -- --keep-going
```

---

## Continuous Integration

The GitHub Actions workflow (`.github/workflows/lint.yml`) triggers on pushes to `main` and on pull requests. It runs two jobs:

**lint:** Generates synthetic test data (`generate_test_data.py`), runs `snakemake --lint`, and validates the DAG with a dry run against the test profile.

**test:** Executes the full 119-job pipeline end-to-end on synthetic data using the test profile. Conda environments are cached by hashing `rules/envs/**/*.yaml`. The test profile loads `config_test.yaml` to relax QC thresholds. Results and logs are uploaded as artifacts with 7-day retention.

Both jobs must pass before merging.

---

## Extending the Pipeline

### Step 1: Create a rule file

Copy `rules/template_tool.smk` and adapt it:

```python
# rules/my_new_tool.smk
rule my_new_tool:
    input:
        bam=lambda wc: f"{config['my_new_tool']['input']}/{wc.sample}.filtered.shifted.bam"
    output:
        result=f"{config['my_new_tool']['output']}/{{sample}}_result.txt"
    params:
        extra=config['my_new_tool']['params']['extra']
    conda: "envs/05_peak_calling/my_new_tool.yaml"
    container: "https://depot.galaxyproject.org/singularity/my_new_tool:1.0--0"
    threads: config['my_new_tool']['threads']
    resources:
        mem_mb=config['my_new_tool']['resources']['mem_mb'],
        time=config['my_new_tool']['resources']['time']
    log: "logs/my_new_tool/{sample}.err"
    benchmark: "benchmarks/my_new_tool/{sample}.txt"
    shell:
        "my_new_tool --input {input.bam} --output {output.result} {params.extra} 2> {log}"
```

### Step 2: Create a Conda environment

```yaml
# rules/envs/05_peak_calling/my_new_tool.yaml
channels:
  - conda-forge
  - bioconda
dependencies:
  - my_new_tool=1.0
```

### Step 3: Add a config block

```yaml
# In config.yaml
my_new_tool:
  input: "results/post_alignment/tn5_shift"
  output: "results/peak_calling/my_new_tool"
  params:
    extra: "--verbose"
  threads: 4
  resources:
    mem_mb: 8000
    time: 120
```

### Step 4: Register in Snakefile

```python
include: "rules/my_new_tool.smk"

PEAK_TARGETS = [
    # ... existing targets ...
    expand("{path}/{sample}_result.txt", path=config['my_new_tool']['output'], sample=SAMPLES),
]
```

---

## Repository Structure

```
.
├── Snakefile                          # DAG definition, mode switching, target assembly
├── config.yaml                        # All parameters, paths, thresholds, resources
├── profile/
│   ├── local/config.yaml              # 8 parallel jobs, 4 GB default
│   ├── low_resource/config.yaml       # 2 jobs, per-rule memory caps for 40+ rules
│   ├── slurm/config.yaml              # 100 jobs, SLURM executor, latency-wait 60
│   └── test/
│       ├── config.yaml                # 4 jobs, loads config_test.yaml
│       └── config_test.yaml           # QC gate thresholds set to 0 for synthetic data
├── rules/
│   ├── fastp.smk                      # Adapter trimming (fastp)
│   ├── fastqc.smk                     # Read quality (FastQC)
│   ├── bowtie2.smk                    # Alignment (Bowtie2 --very-sensitive)
│   ├── samtools_sort.smk              # Coordinate sorting
│   ├── samtools_fixmate.smk           # Mate pair correction
│   ├── samtools_markdup.smk           # Duplicate marking
│   ├── samtools_view.smk              # MAPQ/flag filtering (q30, -F 3844, -f 2)
│   ├── remove_blacklist_reads.smk     # ENCODE blacklist removal (bedtools)
│   ├── tn5_shift.smk                  # Tn5 offset (alignmentSieve --ATACshift)
│   ├── macs2_peak_calling.smk         # Peak calling (BAMPE, --nomodel)
│   ├── idr.smk                        # Replicate concordance (IDR 0.05)
│   ├── consensus_peaks.smk            # Merged peaks (bedtools merge -d 100)
│   ├── differential_accessibility.smk # DESeq2 differential analysis
│   ├── footprinting.smk               # HINT-ATAC (rgt-hint)
│   ├── tobias.smk                     # TOBIAS ATACorrect + BINDetect
│   ├── chromvar_analysis.smk          # chromVAR motif deviations
│   ├── peak_annotation.smk            # ChIPseeker genomic annotation
│   ├── motif_analysis.smk             # HOMER motif enrichment
│   ├── heatmap.smk                    # deepTools heatmaps
│   ├── correlation_analysis.smk       # deepTools sample correlation
│   ├── multiqc.smk                    # Aggregated QC report
│   ├── benchmark_summary.smk          # Runtime/memory aggregation
│   ├── template_tool.smk              # Boilerplate for new rules
│   ├── chromap.smk                    # scATAC alignment (Chromap)
│   ├── archr.smk                      # scATAC analysis (ArchR)
│   ├── cicero.smk                     # Co-accessibility (Cicero)
│   ├── envs/                          # Conda environments (8 categories)
│   │   ├── 01_preprocessing/
│   │   ├── 02_alignment/
│   │   ├── 03_post_alignment/
│   │   ├── 04_metrics_qc/
│   │   ├── 05_peak_calling/
│   │   ├── 06_visualization/
│   │   ├── misc/
│   │   └── scatac/
│   └── scripts/
│       ├── validate_config.py         # Pre-flight config + sample sheet validator
│       ├── run_batched.py             # Sequential sample batching for low-RAM machines
│       ├── generate_test_data.py      # Synthetic FASTQ/reference generator for CI
│       ├── parse_qc_metrics.py        # QC gate metric evaluation
│       ├── tss_enrichment.R           # TSS enrichment scoring
│       ├── chromvar_analysis.R        # chromVAR deviation computation
│       └── diff_accessibility.R       # DESeq2 differential analysis + plots
├── data/
│   ├── fastp/samples.tsv              # Sample sheet
│   ├── fastq/                         # Raw FASTQ files
│   ├── reference/                     # Genome, Bowtie2 index, blacklist, GTF
│   └── motifs/                        # JASPAR motif database (MEME format)
├── .github/workflows/lint.yml         # CI: lint + dry-run + full pipeline test
├── CHANGELOG.md
├── CITATION.cff
├── CONTRIBUTING.md
└── LICENSE
```

---

## Citation

```
Bhandary, H. (2026). BDB-Genomics ATAC-seq Framework (Version 3.0.0).
https://github.com/BDB-Genomics/atacseq-pipeline
```

See `CITATION.cff` for a machine-readable citation format.

## License

MIT License. See [LICENSE](LICENSE) for details.
