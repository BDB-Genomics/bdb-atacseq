#!/usr/bin/env python3
"""
Chromatin Velocity CLI - Main entry point for the Snakemake pipeline.

Usage:
    python chromatin_velocity/run.py \
        --fragment-file fragments.tsv.gz \
        --embedding embedding.csv \
        --output-dir results/chromatin_velocity \
        --n-neighbors 30
"""

import argparse
import logging
import sys
from pathlib import Path
import numpy as np
import pandas as pd

from .fragment_analysis import (
    extract_fragment_sizes,
    classify_fragments,
    compute_nfr_ratio,
    compute_fragment_size_distribution,
    compute_nucleosome_periodicity,
)
from .velocity import (
    build_knn_graph,
    compute_velocity_vectors,
    compute_transition_probabilities,
)
from .visualization import (
    plot_velocity_stream,
    plot_nfr_ratio_violin,
    plot_fragment_size_distribution,
    plot_velocity_quiver,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


def main():
    parser = argparse.ArgumentParser(
        description="Chromatin Velocity: Infer cell trajectories from nucleosome dynamics"
    )

    parser.add_argument(
        "--fragment-file",
        required=True,
        help="Path to fragment file (tsv.gz or bed)",
    )
    parser.add_argument(
        "--embedding",
        required=True,
        help="Path to cell embedding CSV (columns: barcode, dim1, dim2, ...)",
    )
    parser.add_argument(
        "--output-dir",
        required=True,
        help="Output directory for results",
    )
    parser.add_argument(
        "--cell-barcodes",
        default=None,
        help="Path to valid cell barcode file (optional)",
    )
    parser.add_argument(
        "--n-neighbors",
        type=int,
        default=30,
        help="Number of neighbors for KNN graph",
    )
    parser.add_argument(
        "--min-fragments",
        type=int,
        default=100,
        help="Minimum fragments per cell",
    )
    parser.add_argument(
        "--smoothing-steps",
        type=int,
        default=3,
        help="Number of velocity smoothing steps",
    )
    parser.add_argument(
        "--cell-annotations",
        default=None,
        help="Path to cell annotation CSV (columns: barcode, cell_type)",
    )
    parser.add_argument(
        "--peaks",
        default=None,
        help="Path to peaks BED file for region-level analysis",
    )

    args = parser.parse_args()

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    logger.info("=" * 60)
    logger.info("Chromatin Velocity Analysis")
    logger.info("=" * 60)

    logger.info("Step 1: Extracting fragment sizes...")
    fragments = extract_fragment_sizes(
        args.fragment_file,
        cell_barcode_file=args.cell_barcodes,
    )

    logger.info("Step 2: Classifying fragments...")
    fragments = classify_fragments(fragments)

    logger.info("Step 3: Computing fragment size distribution...")
    centers, counts = compute_fragment_size_distribution(fragments)
    pd.DataFrame({"size": centers, "count": counts}).to_csv(
        output_dir / "fragment_size_distribution.csv", index=False
    )

    plot_fragment_size_distribution(
        centers, counts,
        output_path=str(output_dir / "fragment_size_distribution.png"),
    )

    repeat_length = compute_nucleosome_periodicity(centers, counts)
    with open(output_dir / "nucleosome_periodicity.txt", "w") as f:
        f.write(f"estimated_repeat_length_bp\t{repeat_length}\n")

    logger.info("Step 4: Computing per-cell NFR ratios...")
    nfr_ratios = compute_nfr_ratio(
        fragments,
        groupby="barcode",
        min_fragments=args.min_fragments,
    )
    nfr_ratios.to_csv(output_dir / "nfr_ratios_per_cell.csv")

    if args.peaks:
        logger.info("Step 4b: Computing region-level NFR ratios...")
        peaks = pd.read_csv(args.peaks, sep="\t", header=None, names=["chrom", "start", "end"])
        region_ratios = compute_region_nfr_ratio(fragments, peaks)
        region_ratios.to_csv(output_dir / "nfr_ratios_per_region.csv")

    logger.info("Step 5: Loading cell embedding...")
    embedding_df = pd.read_csv(args.embedding, index_col=0)
    embedding = embedding_df.values

    valid_cells = nfr_ratios.index.intersection(embedding_df.index)
    if len(valid_cells) < 100:
        logger.error(f"Only {len(valid_cells)} cells have both fragments and embedding data")
        sys.exit(1)

    nfr_ratios = nfr_ratios.loc[valid_cells]
    embedding = embedding_df.loc[valid_cells].values

    logger.info(f"Analyzing {len(valid_cells)} cells with {embedding.shape[1]} dimensions")

    logger.info("Step 6: Building KNN graph...")
    adj, distances, indices = build_knn_graph(
        embedding, n_neighbors=args.n_neighbors
    )

    logger.info("Step 7: Computing velocity vectors...")
    velocity = compute_velocity_vectors(
        nfr_ratios["nfr_ratio"],
        embedding,
        adj=adj,
        smoothing_steps=args.smoothing_steps,
    )

    np.save(output_dir / "velocity_vectors.npy", velocity)

    logger.info("Step 8: Computing transition probabilities...")
    transition = compute_transition_probabilities(velocity, embedding, adj)

    pd.DataFrame.sparse.from_spmatrix(
        transition,
        index=valid_cells,
        columns=valid_cells,
    ).to_csv(output_dir / "transition_probabilities.csv")

    logger.info("Step 9: Generating visualizations...")

    if embedding.shape[1] >= 2:
        plot_velocity_stream(
            embedding[:, :2], velocity[:, :2], nfr_ratios["nfr_ratio"],
            output_path=str(output_dir / "velocity_streamplot.png"),
        )

        plot_velocity_quiver(
            embedding[:, :2], velocity[:, :2], nfr_ratios["nfr_ratio"],
            output_path=str(output_dir / "velocity_quiver.png"),
        )

    cell_annotations = None
    if args.cell_annotations:
        annot_df = pd.read_csv(args.cell_annotations, index_col=0)
        cell_annotations = annot_df.loc[valid_cells, "cell_type"]

    plot_nfr_ratio_violin(
        nfr_ratios["nfr_ratio"],
        cell_annotations=cell_annotations,
        output_path=str(output_dir / "nfr_ratio_violin.png"),
    )

    pd.DataFrame({
        "nfr_ratio": nfr_ratios["nfr_ratio"],
        "nfr_log_ratio": nfr_ratios["nfr_log_ratio"],
        "total_fragments": nfr_ratios["total_fragments"],
    }).to_csv(output_dir / "chromatin_velocity_results.csv")

    logger.info("=" * 60)
    logger.info("Chromatin Velocity analysis complete!")
    logger.info(f"Results saved to: {output_dir}")
    logger.info("=" * 60)


if __name__ == "__main__":
    main()
