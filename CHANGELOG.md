# Changelog

All notable changes to this project will be documented in this file.

## [v3.0.2] - 2026-07-02

### Added
- **AGENTS.md**: Agent entrypoint file for AI coding assistants with navigation map and tool references.
- **OpenWiki Workflow**: `.github/workflows/openwiki-update.yml` for daily automated agent documentation via GitHub Actions.
- **Understand-Anything**: Integrated Egonex-AI codebase analysis plugin with `.gitignore` exclusions for intermediate files.
- **Script Flowcharts**: `rules/scripts/README.md` with expandable Mermaid flowcharts for all Python and R helper scripts.
- **`test_envs.sh`**: Dynamic Conda environment verification script.

### Changed
- **README.md**: Revised with detailed setup instructions, Bowtie2 index building, reference data directory tree, sample sheet schema, config validation steps, and security features table.
- **`run_batched.py`**: Replaced raw `config['key']` lookups with `get_config_path()` helper to prevent `KeyError` at runtime. Added `SAMPLE_NAME_PATTERN` regex that rejects `..` path traversal in sample names.
- **`validate_config.py`**: Updated `SAMPLE_NAME_PATTERN` to reject double-dot sequences.

## [v3.0.1] - 2026-05-22

### Added
- **Global Wildcard Constraints**: Regex constraints for `{sample}`, `{condition}`, and `{replicate}` at the global level in the `Snakefile`.

### Changed
- **`calculate_mito_reads.smk`**: Refactored to include `.bam.bai` as an official input dependency instead of inline indexing.
- **`bedtools_genomecov.smk`**: Dynamically ignores bulk QC when in `scatac` mode.

### Fixed
- **`tobias.smk`**: Corrected BINDetect argument from `--bam` to `--signals`.
- **`bedtools.yaml`**: Added missing `samtools` dependency.
- **`archr.smk`**: Restored missing Singularity `container` directive.
- **`fastp.smk`**: Restored missing whitespace in `threads` directive.
- **`samtools_fixmate.smk`**: Normalized log and benchmark extensions.
- **`Snakefile`**: Standardized CI block to define `SAMPLES_TSV = None` under `IS_CI` mode.

## [v3.0.0] - 2026-05-17

### Added
- **CLI Mode Switching**: `ATAC_MODE=bulk` or `ATAC_MODE=scatac` environment variable switches entire pipeline between modalities.
- **Chromap Alignment**: Fast single-cell ATAC-seq aligner with `--preset atac`.
- **ArchR Pipeline**: Arrow file creation, doublet detection, iterative LSI, UMAP clustering, marker gene identification.
- **Cicero Co-accessibility**: Chromatin co-accessibility networks and CCAN identification.
- **scATAC-seq Conda Environments**: chromap, archr, cicero environments with all dependencies.

### Changed
- **Snakefile**: Conditional includes based on `MODE` variable.
- **README**: Complete rewrite with scATAC-seq section.

## [v2.1.0] - 2026-05-17

### Added
- **TOBIAS Footprinting Suite**: Full TOBIAS pipeline (ATACorrect, ScoreBigwig, BINDetect).
- **Low-Resource Profile**: `profile/low_resource/` for machines with ≤8GB RAM.
- **Sequential Sample Batching**: `run_batched.py` for ultra-low-resource machines.

## [v2.0.0] - 2026-05-17

### Added
- **IDR Replicate Concordance**: Irreproducible Discovery Rate analysis for peak validation.
- **NSC/RSC Cross-Correlation**: ENCODE-compliant strand cross-correlation metrics.
- **Consensus Peak Calling**: Multi-sample peak merging with configurable thresholds.
- **Differential Accessibility**: DESeq2-based analysis with volcano, MA, PCA, and heatmap plots.
- **Benchmark Aggregation**: Multi-rule performance summary.
- **Test Profile**: `profile/test/` for CI with auto-generated test data.
- **CI/CD Pipeline**: Two-stage workflow (lint + test) with micromamba and artifact upload.

### Changed
- **QC Gate Enforcement**: Downstream rules now require `_qc_pass.txt` input.

### Fixed
- `fastp.yaml`: Invalid version `1.3.3` → `0.24.0`.
- `tss_enrichment.yaml`: Added 7 missing Bioconductor packages.
- `fragment_size_analysis.smk`: Wrong conda env.
- `frip_calculation.smk`: Chromosome naming mismatch.
- `preseq.smk`: Removed `|| true` failure silencing.
- `bowtie2.smk`: Hardcoded `--very-sensitive` → config parameter.
- `blacklist_filter.smk`: Removed fragile awk chr-prefix logic.

## [v1.1.0] - 2026-05-15

### Added
- **Production-Ready Architecture**: Fully reactive and modular Snakemake framework.
- **Dynamic Configuration**: All target paths migrated to `config.yaml` references.
- **QC Gating**: Biological checkpoint system for TSS and FRiP validation.
- **Lifecycle Hooks**: `onstart`, `onsuccess`, and `onerror` handlers.
- **Proactive Validation**: `validate_config.py` for schema checking at parse time.
- Core processes: fastp, FastQC, Bowtie2, Samtools, MACS2, BigWig, heatmaps, motif analysis, correlation plots.

### Changed
- **Standardized Directives**: Uniform 10-directive layout across all `.smk` files.
- **Global Containerization**: Stable Singularity containers via Biocontainers.
- **Environment Hierarchy**: Stage-based `rules/envs/` structure.

### Fixed
- Redundant and missing includes in `Snakefile`.
- `motif_analysis` directory resolution issues.
- Log and benchmark path inconsistencies.
