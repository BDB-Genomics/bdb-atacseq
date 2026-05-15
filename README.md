# BDB-Genomics ATAC-seq Pipeline (V1.1.0)

A standardized, modular Snakemake framework for the comprehensive analysis of paired-end ATAC-seq data. This pipeline is engineered for high reproducibility, scalability, and rigorous quality control, adhering to modern bioinformatics best practices.

## Architectural Principles
- **Dynamic Reactivity**: The workflow utilizes a configuration-driven DAG (Directed Acyclic Graph) architecture. All I/O paths and computational targets are resolved at runtime via `config.yaml`, ensuring portability across diverse high-performance computing (HPC) environments.
- **Reproducibility**: Global integration with **Biocontainers** (Singularity/Docker) and hierarchical Conda environment definitions ensures consistent tool versioning and execution environments.
- **Fail-Fast Validation**: A proactive pre-flight validation system (`validate_config.py`) audits the configuration schema and sample metadata before execution, preventing runtime failures due to missing dependencies or malformed inputs.

## Pipeline Components
1. **Preprocessing**: Raw read quality assessment (FastQC) and adapter trimming (fastp).
2. **Alignment**: Genomic mapping utilizing Bowtie2, followed by Samtools-based sorting and deduplication.
3. **Post-Alignment Processing**: Mitochondrial read removal, Tn5 shift correction, and coordinate-sorted indexing.
4. **Quality Metrics**: Assessment of fragment size distribution, TSS enrichment profiles (custom R implementation), and library complexity (Preseq).
5. **Peak Analysis**: Enrichment calling (MACS2), blacklist filtering (ENCODE), and genomic annotation (ChIPseeker).
6. **Visualization & Reporting**: Generation of normalized BigWig tracks, heatmaps, and comprehensive MultiQC aggregation.

## Biological Quality Control (QC) Gate
The framework implements an automated gating system to ensure data integrity. Samples must meet user-defined thresholds for:
- **TSS Enrichment Score**: Signal-to-noise ratio at transcription start sites.
- **Fraction of Reads in Peaks (FRiP)**: Quantification of biological enrichment.
- **Library Metrics**: Assessment of mapping rates and duplication levels.

Failures in these metrics trigger an automated termination of the specific sample's workflow to preserve computational resources and prevent invalid downstream analysis.

## Usage

### Prerequisites
- Snakemake ≥ 7.0
- Conda or Singularity/Apptainer

### Execution
1. Configure the workflow by modifying `config.yaml` and populating the sample sheet at `data/fastp/samples.tsv`.
2. Perform a dry-run to verify the DAG and configuration:
   ```bash
   snakemake --dry-run
   ```
3. Execute the workflow:
   ```bash
   snakemake --use-conda --use-singularity --cores <n_threads>
   ```

## Repository Structure
- `Snakefile`: Main entry point and lifecycle management.
- `config.yaml`: Central configuration for tools and paths.
- `rules/`: Modular Snakemake rule definitions.
- `rules/envs/`: Hierarchical environment configurations.
- `rules/scripts/`: Custom analytical and validation scripts.

## Citation
If you utilize this framework in your research, please cite the repository as follows:

Bhandary, H. (2026). *BDB-Genomics ATAC-seq Framework (Version 1.1.0)*. BDB-Genomics GitHub Repository. https://github.com/BDB-Genomics/atacseq-pipeline

## License
This project is licensed under the MIT License - see the `LICENSE` file for details.
