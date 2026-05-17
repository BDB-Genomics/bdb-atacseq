# Chromatin Velocity

> **Infer cell trajectory direction from nucleosome dynamics in scATAC-seq data**

## Overview

Chromatin Velocity is a novel algorithm that uses the ratio of nucleosome-free (<147bp) to mononucleosomal (>=147bp) reads in single-cell ATAC-seq data to infer the direction of cell state transitions.

### Core Hypothesis

As cells differentiate, chromatin undergoes systematic reorganization:
- **Progenitor/stem cells**: More open chromatin, higher proportion of nucleosome-free fragments
- **Differentiated cells**: More structured nucleosome positioning, higher proportion of mononucleosomal fragments

The **NFR/MonoNuc ratio** provides a directional signal for trajectory inference that is:
- **Reference-free**: No pre-defined clock loci needed (unlike EpiTrace)
- **ATAC-only**: Works on scATAC-seq alone (unlike ArchVelo which needs multi-omics)
- **Directional**: Distinguishes forward differentiation from dedifferentiation

## Installation

```bash
# Via conda (recommended)
conda env create -f rules/envs/chromatin_velocity.yaml
conda activate chromatin_velocity

# Or via pip
pip install numpy pandas scipy scikit-learn matplotlib seaborn pyranges pysam
```

## Usage

### As part of the ATAC-seq pipeline

Set `mode: "scatac"` in `config.yaml` and run:

```bash
snakemake --cores all --profile profile/low_resource
```

### Standalone CLI

```bash
python -m chromatin_velocity.run \
    --fragment-file fragments.tsv.gz \
    --embedding umap_coordinates.csv \
    --cell-barcodes cell_barcodes.txt \
    --peaks peaks.bed \
    --cell-annotations cell_clusters.tsv \
    --output-dir results/chromatin_velocity \
    --n-neighbors 30 \
    --min-fragments 100
```

### As a Python library

```python
from chromatin_velocity import (
    extract_fragment_sizes,
    compute_nfr_ratio,
    build_knn_graph,
    compute_velocity_vectors,
    plot_velocity_stream,
)

# Extract and classify fragments
fragments = extract_fragment_sizes("fragments.tsv.gz")
nfr_ratios = compute_nfr_ratio(fragments, min_fragments=100)

# Compute velocity
embedding = load_embedding("umap.csv")  # n_cells x 2
adj = build_knn_graph(embedding, n_neighbors=30)[0]
velocity = compute_velocity_vectors(nfr_ratios["nfr_ratio"], embedding, adj=adj)

# Visualize
plot_velocity_stream(embedding, velocity, nfr_ratios["nfr_ratio"])
```

## Output Files

| File | Description |
|------|-------------|
| `nfr_ratios_per_cell.csv` | Per-cell NFR ratios and statistics |
| `velocity_vectors.npy` | Velocity vectors for each cell |
| `transition_probabilities.csv` | Cell-to-cell transition probabilities |
| `fragment_size_distribution.csv` | Genome-wide fragment size histogram |
| `nucleosome_periodicity.txt` | Estimated nucleosome repeat length |
| `velocity_streamplot.png` | Velocity field streamplot |
| `velocity_quiver.png` | Velocity quiver plot |
| `nfr_ratio_violin.png` | NFR ratio distribution by cell type |
| `chromatin_velocity_summary.tsv` | Summary statistics |

## Algorithm

1. **Fragment Extraction**: Parse fragment file or BAM to get per-fragment sizes
2. **Classification**: Label fragments as NFR (<147bp) or MonoNuc (>=147bp)
3. **Ratio Calculation**: Compute per-cell NFR ratio = NFR / (NFR + MonoNuc)
4. **KNN Graph**: Build neighbor graph in embedding space
5. **Velocity Estimation**: Compute velocity vectors from NFR ratio gradients
6. **Visualization**: Project velocity onto 2D embedding for streamplot

## Validation

Recommended validation datasets:
- **ENCODE GM12878**: Bulk ATAC-seq for fragment size distribution validation
- **10x Genomics PBMC**: scATAC-seq with known cell types
- **Bone marrow hematopoiesis**: Known differentiation trajectory

## Citation

If you use Chromatin Velocity in your research, please cite:

```
Bhandary, H. et al. "Chromatin Velocity: Inferring cell trajectories from nucleosome dynamics." (2026)
```

## License

MIT License - see LICENSE file for details.
