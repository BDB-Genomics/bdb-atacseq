"""
Chromatin Velocity - Inferring cell trajectory direction from nucleosome dynamics.

Core hypothesis: The ratio of nucleosome-free (<147bp) to mononucleosomal (>=147bp)
reads in scATAC-seq data provides a directional signal for cell state transitions.
"""

__version__ = "0.1.0"
__author__ = "Himanshu Bhandary"
__email__ = "2032ushimanshu@gmail.com"

from .fragment_analysis import (
    extract_fragment_sizes,
    classify_fragments,
    compute_nfr_ratio,
)
from .velocity import (
    build_knn_graph,
    compute_velocity_vectors,
    project_velocity,
)
from .visualization import (
    plot_velocity_stream,
    plot_nfr_ratio_violin,
    plot_velocity_genes,
)

__all__ = [
    "extract_fragment_sizes",
    "classify_fragments",
    "compute_nfr_ratio",
    "build_knn_graph",
    "compute_velocity_vectors",
    "project_velocity",
    "plot_velocity_stream",
    "plot_nfr_ratio_violin",
    "plot_velocity_genes",
]
