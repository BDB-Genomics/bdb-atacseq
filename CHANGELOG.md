#Changelog
#Notable changes made to the pipeline will be recorded in this file 

## [Unreleased]
- Placeholder for upcoming features, bug fixes or improvements.

## [V3.0.1] - 2026-05-22
### Added
- **Global Wildcard Constraints**: Added regex constraints for `{sample}` (`[^/]+`), `{condition}` (`[^/]+`), and `{replicate}` (`[0-9]+`) at the global level in the `Snakefile` to prevent ambiguous path matching and ensure robust DAG resolution.

### Changed
- **calculate_mito_reads.smk**: Refactored to include `.bam.bai` as an official Snakemake input dependency instead of executing an inline indexing command in the shell directive, preventing potential job race conditions.
- **bedtools_genomecov.smk**: Modified to dynamically ignore bulk QC (`qc_pass` file) when the pipeline is switched to `scatac` mode, allowing scATAC-seq target coverage rules to execute seamlessly.

### Fixed
- **tobias.smk**: Corrected TOBIAS BINDetect argument from `--bam` to `--signals` to prevent runtime crashes during bias-corrected TF footprinting.
- **bedtools.yaml**: Added missing `samtools` dependency to the `03_post_alignment/bedtools` conda environment to resolve runtime failures in FRiP calculation.
- **archr.smk**: Restored the missing galaxy project Singularity `container` directive for the `archr_doublet_detection` rule.
- **fastp.smk**: Restored missing whitespace in `threads: config["fastp"]["threads"]` directive.
- **samtools_fixmate.smk**: Normalized log and benchmark extensions (`.err` and `.txt`) to maintain consistency with the global framework logging convention.
- **Snakefile**: Standardized CI block to define `SAMPLES_TSV = None` under `IS_CI` mode, avoiding a potential `NameError` on empty sample checks.

## [V3.0.0] - 2026-05-17
### Added
- **CLI Mode Switching**: `ATAC_MODE=bulk` or `ATAC_MODE=scatac` environment variable switches entire pipeline between bulk and single-cell modes — no manual file editing required
- **Chromap Alignment**: Fast single-cell ATAC-seq aligner with `--preset atac`
- **ArchR Pipeline**: Arrow file creation, doublet detection/filtering, iterative LSI, UMAP clustering, marker gene identification
- **Cicero Co-accessibility**: Chromatin co-accessibility networks, CCAN identification, connection scoring
- **scATAC-seq Conda Environments**: chromap, archr, cicero environments with all dependencies
- **scATAC-seq Config Blocks**: chromap, archr, cicero configuration sections in config.yaml
- **global.mode**: New config key (`bulk` or `scatac`) for declarative mode selection

### Changed
- **Snakefile**: Conditional includes based on `MODE` variable — bulk and scATAC-seq rules are mutually exclusive
- **README**: Complete rewrite of scATAC-seq section — now a one-command switch instead of manual edits
- **Comparison Table**: Added scATAC-seq, Cicero, and mode switching rows

## [V2.1.0] - 2026-05-17
### Added
- **TOBIAS Footprinting Suite**: Full TOBIAS pipeline (ATACorrect, ScoreBigwig, BINDetect) for bias-corrected TF footprinting and differential TF binding analysis
- **Low-Resource Profile**: `profile/low_resource/` for machines with ≤8GB RAM, ≤4 cores
- **Sequential Sample Batching**: `run_batched.py` script for ultra-low-resource machines (≤4GB RAM)

## [V2.0.0] - 2026-05-17
### Added
- **IDR Replicate Concordance**: Irreproducible Discovery Rate analysis for biological replicate peak validation
- **NSC/RSC Cross-Correlation**: ENCODE-compliant strand cross-correlation metrics via phantompeakqualtools
- **Consensus Peak Calling**: Multi-sample peak merging with configurable minimum sample threshold
- **Differential Accessibility**: DESeq2-based analysis with volcano plots, MA plots, PCA, and heatmaps
- **Peak Count Matrix**: bedtools-based read counting in consensus peaks for all samples
- **Benchmark Aggregation**: Multi-rule performance summary across all pipeline stages
- **Test Profile**: `profile/test/` for CI validation with auto-generated test data
- **Test Data Generator**: `generate_test_data.py` creates minimal FASTQ, genome, and annotation files
- **CI/CD Pipeline**: Two-stage workflow (lint + test) with micromamba and artifact upload

### Changed
- **QC Gate Enforcement**: Downstream rules (macs2, bedtools, heatmap, peak_annotation, normalize_coverage) now require `_qc_pass.txt` input
- **motif_analysis**: Per-sample execution with HOMER assembly name instead of FASTA path
- **cross_correlation**: Added as ENCODE-compliant QC metric
- **README**: Complete rewrite with feature comparison table
- **Version**: Bumped to V2.0.0 for production-grade feature set

### Fixed
- `fastp.yaml`: Invalid version `1.3.3` → `0.24.0`
- `tss_enrichment.yaml`: Added 7 missing Bioconductor packages
- `fragment_size_analysis.smk`: Wrong conda env (samtools → fragment_analysis with R)
- `frip_calculation.smk`: Chromosome naming mismatch (removed `sed 's/^chr//g'`)
- `preseq.smk`: Removed `|| true` failure silencing
- `samtools_sort.smk`: Log redirection on separate line
- `samtools_fixmate.smk`: Added `set -o pipefail`
- `bowtie2.smk`: Hardcoded `--very-sensitive` → config parameter
- `blacklist_filter.smk`: Removed fragile awk chr-prefix logic
- `remove_mito_reads.smk`: Regex match → exact chromosome match
- `tss_enrichment.R`: Removed DEBUG print statement
- `validate_config.py`: "ChIP-seq" → "ATAC-seq" docstring
- `.gitignore`: Removed invalid `.../` syntax
- `bedtools.yaml`/`samtools.yaml`: Added `bc` dependency
- `profile/slurm/config.yaml`: Replaced placeholder account, added `latency-wait`
- `.github/workflows/lint.yml`: Fixed YAML indentation, added micromamba, pinned pulp version

## [V1.1.0] - 2026-05-15
- First release of the modular ATAC-seq Pipeline
- Core Processes:
  - Preprocessing: fastp, FastQC
  - Alignment: Bowtie2, Samtools sorting, indexing, and deduplication
  - Post-Alignment QC: mitochondrial read quantification, fragment size analysis, TSS enrichment, PhantomPeakQualTools, Preseq, Qualimap
  - Coverage and normalization: genome coverage, bigwig conversion, CPM normalization
  - Peak Calling and Filtering: MACS2, ENCODE blacklist filtering 
  - Visualization: heatmaps, motif analysis, correlation plots
- Design Features: 
 - Modular Snakefile  with per-rule configuration
 - Configurable via `config.yaml`
 - Optimized for scalability and reproducibility across datasets
 
## [V1.1.0] - 2026-05-15
### Added
- **Production-Ready Architecture**: Implemented a fully reactive and modular Snakemake framework.
- **Dynamic Configuration**: Migrated all target paths in `Snakefile` to dynamic `config.yaml` references, ensuring total portability.
- **QC Gating**: Integrated a biological checkpoint system to validate metrics (TSS, FRiP) before expensive downstream analysis.
- **Lifecycle Hooks**: Added `onstart`, `onsuccess`, and `onerror` handlers for automated status reporting.
- **Proactive Validation**: Integrated `validate_config.py` to catch schema errors at parse time.

### Changed
- **Standardized Directives**: Enforced a uniform 10-directive layout across all 34 `.smk` files (log, conda, container, resources, etc.).
- **Global Containerization**: Switched all rules to use stable Singularity containers via Biocontainers for 100% reproducibility.
- **Environment Hierarchy**: Refactored `rules/envs/` into a stage-based hierarchical structure matching the pipeline stages.
- **Cleaned Root Directory**: Removed legacy scripts, runtime artifacts, and unused directories (`benchmarks/`, `scratch/`, `scripts/`).

### Fixed
- Resolved redundant and missing includes in the main `Snakefile`.
- Corrected `motif_analysis` directory resolution issues.
- Standardized log and benchmark paths across the entire framework.


