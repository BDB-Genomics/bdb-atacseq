"""
Visualization utilities for Chromatin Velocity.

Generates streamplots, violin plots, and gene-specific velocity visualizations.
"""

import numpy as np
import pandas as pd
from typing import Optional, Tuple
import logging

logger = logging.getLogger(__name__)


def plot_velocity_stream(
    embedding: np.ndarray,
    velocity: np.ndarray,
    nfr_ratios: pd.Series,
    output_path: str = "velocity_streamplot.png",
    grid_size: int = 50,
    density: float = 1.5,
    cmap: str = "viridis",
    figsize: Tuple[int, int] = (10, 8),
    title: Optional[str] = None,
):
    """
    Generate a streamplot of velocity vectors overlaid on cell embedding.

    Parameters
    ----------
    embedding : np.ndarray
        2D cell embedding (n_cells x 2).
    velocity : np.ndarray
        Velocity vectors (n_cells x 2).
    nfr_ratios : pd.Series
        Per-cell NFR ratios for coloring.
    output_path : str
        Path to save the plot.
    grid_size : int
        Grid resolution for streamplot.
    density : float
        Streamline density.
    cmap : str
        Colormap for cell coloring.
    figsize : Tuple[int, int]
        Figure size.
    title : str, optional
        Plot title.
    """
    import matplotlib.pyplot as plt
    from matplotlib import cm
    from .velocity import project_velocity

    Xi, Yi, Ui, Vi = project_velocity(velocity, embedding, grid_size=grid_size)

    fig, ax = plt.subplots(figsize=figsize)

    scatter = ax.scatter(
        embedding[:, 0], embedding[:, 1],
        c=nfr_ratios.values,
        cmap=cmap,
        s=5,
        alpha=0.6,
        zorder=1,
    )
    plt.colorbar(scatter, ax=ax, label="NFR Ratio")

    ax.streamplot(
        Xi, Yi, Ui, Vi,
        color="white",
        density=density,
        linewidth=0.8,
        arrowsize=1.2,
        zorder=2,
    )

    if title:
        ax.set_title(title)
    else:
        ax.set_title("Chromatin Velocity Streamplot")

    ax.set_xlabel("Embedding Dimension 1")
    ax.set_ylabel("Embedding Dimension 2")
    ax.set_xticks([])
    ax.set_yticks([])

    plt.tight_layout()
    plt.savefig(output_path, dpi=300, bbox_inches="tight")
    plt.close()

    logger.info(f"Velocity streamplot saved to {output_path}")


def plot_nfr_ratio_violin(
    nfr_ratios: pd.Series,
    cell_annotations: Optional[pd.Series] = None,
    output_path: str = "nfr_ratio_violin.png",
    figsize: Tuple[int, int] = (10, 6),
    title: Optional[str] = None,
):
    """
    Generate violin plot of NFR ratios by cell type.

    Parameters
    ----------
    nfr_ratios : pd.Series
        Per-cell NFR ratios.
    cell_annotations : pd.Series, optional
        Per-cell type annotations.
    output_path : str
        Path to save the plot.
    figsize : Tuple[int, int]
        Figure size.
    title : str, optional
        Plot title.
    """
    import matplotlib.pyplot as plt
    import seaborn as sns

    df = pd.DataFrame({"nfr_ratio": nfr_ratios})

    if cell_annotations is not None:
        df["cell_type"] = cell_annotations
        x_col = "cell_type"
        x_label = "Cell Type"
    else:
        df["cell_type"] = "All"
        x_col = "cell_type"
        x_label = ""

    fig, ax = plt.subplots(figsize=figsize)

    sns.violinplot(
        data=df,
        x=x_col,
        y="nfr_ratio",
        ax=ax,
        inner="quartile",
        palette="Set2",
    )

    ax.axhline(y=0.5, color="red", linestyle="--", alpha=0.5, label="NFR = MonoNuc")
    ax.legend()

    if title:
        ax.set_title(title)
    else:
        ax.set_title("NFR Ratio Distribution")

    ax.set_xlabel(x_label)
    ax.set_ylabel("NFR Ratio")

    if cell_annotations is not None:
        plt.xticks(rotation=45, ha="right")

    plt.tight_layout()
    plt.savefig(output_path, dpi=300, bbox_inches="tight")
    plt.close()

    logger.info(f"NFR ratio violin plot saved to {output_path}")


def plot_velocity_genes(
    gene_velocity_scores: pd.DataFrame,
    top_n: int = 20,
    output_path: str = "velocity_genes.png",
    figsize: Tuple[int, int] = (8, 10),
    title: Optional[str] = None,
):
    """
    Generate bar plot of top genes by velocity score.

    Parameters
    ----------
    gene_velocity_scores : pd.DataFrame
        DataFrame with gene names and velocity scores.
    top_n : int
        Number of top genes to display.
    output_path : str
        Path to save the plot.
    figsize : Tuple[int, int]
        Figure size.
    title : str, optional
        Plot title.
    """
    import matplotlib.pyplot as plt
    import seaborn as sns

    top_genes = gene_velocity_scores.nlargest(top_n, "velocity_score")

    fig, ax = plt.subplots(figsize=figsize)

    sns.barplot(
        data=top_genes,
        y="gene",
        x="velocity_score",
        ax=ax,
        palette="viridis",
    )

    if title:
        ax.set_title(title)
    else:
        ax.set_title(f"Top {top_n} Genes by Chromatin Velocity Score")

    ax.set_xlabel("Velocity Score")
    ax.set_ylabel("")

    plt.tight_layout()
    plt.savefig(output_path, dpi=300, bbox_inches="tight")
    plt.close()

    logger.info(f"Velocity genes plot saved to {output_path}")


def plot_fragment_size_distribution(
    centers: np.ndarray,
    counts: np.ndarray,
    output_path: str = "fragment_size_distribution.png",
    figsize: Tuple[int, int] = (10, 6),
    title: Optional[str] = None,
    highlight_nfr: bool = True,
):
    """
    Plot fragment size distribution with NFR/MonoNuc regions highlighted.

    Parameters
    ----------
    centers : np.ndarray
        Fragment size bin centers.
    counts : np.ndarray
        Fragment size counts.
    output_path : str
        Path to save the plot.
    figsize : Tuple[int, int]
        Figure size.
    title : str, optional
        Plot title.
    highlight_nfr : bool
        Whether to highlight NFR region.
    """
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=figsize)

    ax.plot(centers, counts, color="steelblue", linewidth=1)

    if highlight_nfr:
        ax.axvline(x=147, color="red", linestyle="--", alpha=0.7, label="147 bp (MonoNuc)")
        ax.axvspan(0, 147, alpha=0.1, color="green", label="NFR (<147 bp)")
        ax.axvspan(147, 294, alpha=0.1, color="orange", label="MonoNuc (147-294 bp)")
        ax.legend()

    if title:
        ax.set_title(title)
    else:
        ax.set_title("Fragment Size Distribution")

    ax.set_xlabel("Fragment Size (bp)")
    ax.set_ylabel("Count")
    ax.set_xlim(0, min(500, centers.max()))

    plt.tight_layout()
    plt.savefig(output_path, dpi=300, bbox_inches="tight")
    plt.close()

    logger.info(f"Fragment size distribution plot saved to {output_path}")


def plot_velocity_quiver(
    embedding: np.ndarray,
    velocity: np.ndarray,
    nfr_ratios: pd.Series,
    output_path: str = "velocity_quiver.png",
    subsample: int = 10,
    scale: float = 50.0,
    cmap: str = "viridis",
    figsize: Tuple[int, int] = (10, 8),
    title: Optional[str] = None,
):
    """
    Generate quiver plot of velocity vectors.

    Parameters
    ----------
    embedding : np.ndarray
        2D cell embedding (n_cells x 2).
    velocity : np.ndarray
        Velocity vectors (n_cells x 2).
    nfr_ratios : pd.Series
        Per-cell NFR ratios for coloring.
    output_path : str
        Path to save the plot.
    subsample : int
        Subsample factor for arrows.
    scale : float
        Arrow scale factor.
    cmap : str
        Colormap for cell coloring.
    figsize : Tuple[int, int]
        Figure size.
    title : str, optional
        Plot title.
    """
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=figsize)

    scatter = ax.scatter(
        embedding[:, 0], embedding[:, 1],
        c=nfr_ratios.values,
        cmap=cmap,
        s=5,
        alpha=0.5,
        zorder=1,
    )
    plt.colorbar(scatter, ax=ax, label="NFR Ratio")

    mask = np.arange(0, len(embedding), subsample)
    ax.quiver(
        embedding[mask, 0], embedding[mask, 1],
        velocity[mask, 0], velocity[mask, 1],
        angles="xy",
        scale_units="xy",
        scale=scale,
        color="white",
        alpha=0.7,
        zorder=2,
    )

    if title:
        ax.set_title(title)
    else:
        ax.set_title("Chromatin Velocity Quiver Plot")

    ax.set_xlabel("Embedding Dimension 1")
    ax.set_ylabel("Embedding Dimension 2")

    plt.tight_layout()
    plt.savefig(output_path, dpi=300, bbox_inches="tight")
    plt.close()

    logger.info(f"Velocity quiver plot saved to {output_path}")
