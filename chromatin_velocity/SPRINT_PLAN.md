# Chromatin Velocity: 5-Day Implementation Sprint

## Day 1: Core Fragment Size Analysis Engine
- [x] Literature review and novelty confirmation
- [ ] Fragment size extraction from BAM/fragment files
- [ ] NFR (<147bp) vs MonoNuc (>=147bp) classification
- [ ] Per-cell and per-region ratio calculation
- [ ] Unit tests for fragment classification

## Day 2: Velocity Vector Computation
- [ ] KNN graph construction in accessibility space
- [ ] Velocity vector estimation from NFR/MonoNuc ratios
- [ ] Smoothing and regularization
- [ ] Projection onto low-dimensional embeddings (UMAP/t-SNE)

## Day 3: Integration & Visualization
- [ ] Streamplot generation for velocity fields
- [ ] Gene/region-specific velocity scoring
- [ ] Integration with existing pipeline outputs
- [ ] QC metrics for velocity confidence

## Day 4: Snakemake Integration & Testing
- [ ] Create `chromatin_velocity.smk` rule
- [ ] Add config.yaml entries
- [ ] Create conda environment file
- [ ] Test with synthetic data

## Day 5: Benchmarking & Documentation
- [ ] Run on public dataset (ENCODE GM12878 or 10x PBMC)
- [ ] Compare against EpiTrace and RNA velocity
- [ ] Write documentation and API reference
- [ ] Prepare figures for manuscript
