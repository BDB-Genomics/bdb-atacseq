# Chromatin Velocity: Literature Review & Novelty Analysis

## Date: 2026-05-17

## Objective
Identify existing methods for epigenetic velocity and trajectory inference from scATAC-seq data to ensure the novelty of our proposed "Chromatin Velocity" algorithm based on nucleosome-free vs. mononucleosomal read ratios.

---

## Existing Methods

### 1. EpiTrace (Xiao et al., 2024, Nature Methods)
- **Paper**: "Tracking single-cell evolution using clock-like chromatin accessibility loci" [PMC12084158]
- **Core Method**: Identifies "clock-like" differentially methylated loci (ClockDML) that show predictable chromatin accessibility changes during cell division. Measures the fraction of opened clock-like loci per cell as a proxy for mitotic age.
- **Data Required**: scATAC-seq (single modality)
- **Strengths**:
  - Works on scATAC-seq alone (no RNA needed)
  - Validated across multiple lineages and species
  - Can build phylogenetic trees from clock-like locus similarity
  - Complements RNA velocity and CytoTRACE
- **Limitations**:
  - Requires pre-defined ClockDML reference sets (species/tissue-specific)
  - Accuracy depends heavily on sequencing depth
  - Less accurate with highly imbalanced cell populations
  - Measures cumulative mitotic age, not direction of differentiation
  - Computationally inefficient with full peak sets
- **Key Insight**: Chromatin accessibility at specific loci changes predictably with cell division, but this is a "clock" (scalar age), not a "velocity" (vector direction).

### 2. ArchVelo (Avdeeva et al., 2025, bioRxiv)
- **Paper**: "Archetypal Velocity Modeling for Single-cell Multi-omic Trajectories" [bio_5de769f47224]
- **Core Method**: Uses archetypal analysis to model gene regulation and cell trajectories from simultaneous chromatin accessibility and transcriptomic data. Essentially RNA velocity enhanced with ATAC-seq information.
- **Data Required**: Multi-omic (scATAC-seq + scRNA-seq from same cells)
- **Strengths**:
  - Identifies transcription factor activity along trajectories
  - Improved accuracy over RNA velocity alone
  - Reveals new differentiation trajectories
- **Limitations**:
  - Requires multi-omic data (not ATAC-seq alone)
  - Still fundamentally dependent on RNA splicing kinetics
  - Computationally intensive
- **Key Insight**: Chromatin accessibility improves RNA velocity but is not used as an independent velocity signal.

### 3. RNA Velocity (scVelo, UniTVelo, etc.)
- **Core Method**: Uses ratio of unspliced to spliced mRNA reads to infer direction of gene expression change.
- **Data Required**: scRNA-seq (spliced/unspliced counts)
- **Limitations for ATAC-seq**: Not applicable to ATAC-seq data directly; no splicing information in chromatin accessibility data.

### 4. SnapATAC (Fang et al., 2021)
- **Core Method**: Dimensionality reduction and graph-based trajectory inference for scATAC-seq.
- **Data Required**: scATAC-seq
- **Limitations**: Provides pseudotime ordering but no explicit "velocity" vector; no use of fragment size information.

### 5. NucleoATAC (Schep et al., 2015)
- **Core Method**: Uses structured nucleosome fingerprints in ATAC-seq data to map nucleosome positions and occupancy at high resolution.
- **Data Required**: Bulk or single-cell ATAC-seq
- **Limitations**: Static nucleosome positioning, not dynamic; no trajectory inference.

---

## Novelty Gap Analysis

### What No One Has Done:
**Using fragment size distribution (nucleosome-free <147bp vs. mononucleosomal >=147bp reads) as a direct velocity signal for trajectory inference.**

### Our Proposed Approach: Chromatin Velocity
- **Core Hypothesis**: As cells differentiate, chromatin undergoes systematic reorganization:
  - Progenitor/stem cells: More open chromatin, higher proportion of nucleosome-free fragments
  - Differentiated cells: More structured nucleosome positioning, higher proportion of mononucleosomal fragments
  - The **ratio of NFR/MonoNuc reads per cell** provides a directional signal for trajectory inference

- **Why It's Novel**:
  1. **No existing method uses fragment size ratios for velocity**: Current methods either use (a) accessibility at specific loci (EpiTrace), (b) RNA splicing kinetics (RNA velocity), or (c) dimensionality reduction (SnapATAC). None exploit the inherent fragment size information in ATAC-seq data.
  
  2. **Works on scATAC-seq alone**: Unlike ArchVelo, does not require multi-omic data.
  
  3. **Provides direction, not just age**: Unlike EpiTrace which gives a scalar "mitotic age," our ratio-based approach can distinguish between forward differentiation and dedifferentiation/rejuvenation.
  
  4. **Computationally efficient**: Fragment size calculation is O(n) per cell, much faster than EpiTrace's reference-based approach.
  
  5. **No reference set required**: Unlike EpiTrace which needs pre-defined ClockDML sets, our method is reference-free and works on any dataset.

### Potential Challenges:
1. **Sparsity of scATAC-seq**: Single cells have few fragments; may need aggregation or smoothing.
2. **Tn5 bias**: Insertion bias may affect fragment size distribution; requires correction.
3. **Confounding factors**: Sequencing depth, library preparation, and cell cycle may affect fragment sizes.
4. **Validation**: Need to validate against known differentiation trajectories (e.g., hematopoiesis, neurogenesis).

---

## References

[1] Xiao, Y. et al. "Tracking single-cell evolution using clock-like chromatin accessibility loci." *Nature Methods* (2024). doi:10.1038/s41592-024-02290-x
    https://citations.gxl.ai/papers/PMC12084158

[2] Avdeeva, M. et al. "ArchVelo: Archetypal Velocity Modeling for Single-cell Multi-omic Trajectories." *bioRxiv* (2025). doi:10.1101/2025.09.14.676182
    https://citations.gxl.ai/papers/bio_5de769f47224

[3] Schep, A.N. et al. "Structured nucleosome fingerprints enable high-resolution mapping of chromatin architecture within regulatory regions." *Genome Research* 25, 1573-1585 (2015). doi:10.1101/gr.191261.115
    https://citations.gxl.ai/papers/PMC4617971

[4] Fang, R. et al. "Comprehensive analysis of single cell ATAC-seq data with SnapATAC." *Nature Communications* 12, 1239 (2021). doi:10.1038/s41467-021-21583-9
    https://citations.gxl.ai/papers/PMC7910485

[5] Yang, J. et al. "Size-based expectation maximization for characterizing nucleosome positions and subtypes." *Genome Biology* 25, 239 (2024). doi:10.1186/s13059-024-03423-8
    https://citations.gxl.ai/papers/PMC11529872
