#Changelog
#Notable changes made to the pipeline will be recorded in this file 

## [Unreleased]
- Placeholder for  upcoming features, bug fixes or improvement. 

## [V1.0.0] - 2025-07-29
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


