"""
Velocity vector computation for Chromatin Velocity.

Uses NFR/MonoNuc ratios to infer directional cell state transitions
via KNN graph-based velocity estimation.
"""

import numpy as np
import pandas as pd
from typing import Optional, Tuple, Dict
from scipy.sparse import csr_matrix, issparse
from sklearn.neighbors import NearestNeighbors
import logging

logger = logging.getLogger(__name__)


def build_knn_graph(
    embedding: np.ndarray,
    n_neighbors: int = 30,
    metric: str = "euclidean",
) -> Tuple[csr_matrix, np.ndarray, np.ndarray]:
    """
    Build KNN graph from cell embedding.

    Parameters
    ----------
    embedding : np.ndarray
        Cell embedding matrix (n_cells x n_dims).
    n_neighbors : int
        Number of neighbors for KNN graph.
    metric : str
        Distance metric for neighbor search.

    Returns
    -------
    Tuple[csr_matrix, np.ndarray, np.ndarray]
        Adjacency matrix, distances, and indices.
    """
    logger.info(f"Building KNN graph with {n_neighbors} neighbors")

    nn = NearestNeighbors(n_neighbors=n_neighbors, metric=metric, algorithm="auto")
    nn.fit(embedding)
    distances, indices = nn.kneighbors(embedding)

    n_cells = embedding.shape[0]
    row = np.repeat(np.arange(n_cells), n_neighbors)
    col = indices.flatten()
    data = distances.flatten()

    adj = csr_matrix((data, (row, col)), shape=(n_cells, n_cells))
    adj = (adj + adj.T) / 2

    logger.info(f"KNN graph built: {n_cells} cells, {adj.nnz} edges")
    return adj, distances, indices


def compute_velocity_vectors(
    nfr_ratios: pd.Series,
    embedding: np.ndarray,
    adj: Optional[csr_matrix] = None,
    n_neighbors: int = 30,
    smoothing_steps: int = 3,
    velocity_scale: float = 1.0,
) -> np.ndarray:
    """
    Compute velocity vectors from NFR ratio gradients on KNN graph.

    The velocity for each cell is computed as the weighted average of
    NFR ratio differences to its neighbors, projected back into the
    embedding space.

    Parameters
    ----------
    nfr_ratios : pd.Series
        Per-cell NFR ratios (index = cell barcodes).
    embedding : np.ndarray
        Cell embedding matrix (n_cells x n_dims).
    adj : csr_matrix, optional
        Pre-computed adjacency matrix. If None, computed from embedding.
    n_neighbors : int
        Number of neighbors (used if adj is None).
    smoothing_steps : int
        Number of smoothing iterations.
    velocity_scale : float
        Scaling factor for velocity vectors.

    Returns
    -------
    np.ndarray
        Velocity vectors (n_cells x n_dims).
    """
    if adj is None:
        adj, _, _ = build_knn_graph(embedding, n_neighbors=n_neighbors)

    n_cells = embedding.shape[0]

    ratios = nfr_ratios.values.astype(np.float64)
    ratios = (ratios - np.mean(ratios)) / (np.std(ratios) + 1e-8)

    velocity = np.zeros((n_cells, embedding.shape[1]))

    for step in range(smoothing_steps):
        if issparse(adj):
            adj_norm = adj.copy()
            row_sums = np.array(adj_norm.sum(axis=1)).flatten()
            row_sums[row_sums == 0] = 1
            adj_norm = adj_norm.multiply(1.0 / row_sums[:, np.newaxis])
        else:
            adj_norm = adj / (adj.sum(axis=1, keepdims=True) + 1e-8)

        smoothed_ratios = adj_norm @ ratios

        ratio_diff = smoothed_ratios - ratios

        for i in range(n_cells):
            if issparse(adj):
                neighbors = adj[i].indices
                weights = adj[i].data
            else:
                neighbors = np.where(adj[i] > 0)[0]
                weights = adj[i][neighbors]

            if len(neighbors) == 0:
                continue

            weights = weights / (weights.sum() + 1e-8)
            delta_x = embedding[neighbors] - embedding[i]
            velocity[i] += velocity_scale * (ratio_diff[i] * (delta_x * weights[:, np.newaxis]).sum(axis=0))

    velocity_mag = np.linalg.norm(velocity, axis=1)
    logger.info(
        f"Velocity computed: mean magnitude {velocity_mag.mean():.4f}, "
        f"max {velocity_mag.max():.4f}"
    )

    return velocity


def compute_transition_probabilities(
    velocity: np.ndarray,
    embedding: np.ndarray,
    adj: csr_matrix,
    sigma: float = 1.0,
) -> csr_matrix:
    """
    Compute transition probabilities from velocity vectors.

    Parameters
    ----------
    velocity : np.ndarray
        Velocity vectors (n_cells x n_dims).
    embedding : np.ndarray
        Cell embedding matrix.
    adj : csr_matrix
        Adjacency matrix.
    sigma : float
        Kernel bandwidth for probability computation.

    Returns
    -------
    csr_matrix
        Transition probability matrix.
    """
    n_cells = embedding.shape[0]
    transition = np.zeros((n_cells, n_cells))

    for i in range(n_cells):
        if issparse(adj):
            neighbors = adj[i].indices
        else:
            neighbors = np.where(adj[i] > 0)[0]

        if len(neighbors) == 0:
            continue

        delta_x = embedding[neighbors] - embedding[i]
        cos_sim = (delta_x @ velocity[i]) / (
            np.linalg.norm(delta_x, axis=1) * np.linalg.norm(velocity[i]) + 1e-8
        )

        probs = np.exp(cos_sim / sigma)
        probs /= probs.sum() + 1e-8
        transition[i, neighbors] = probs

    return csr_matrix(transition)


def project_velocity(
    velocity: np.ndarray,
    embedding: np.ndarray,
    grid_size: int = 50,
    smoothing: float = 0.5,
) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """
    Project velocity vectors onto a 2D grid for visualization.

    Parameters
    ----------
    velocity : np.ndarray
        Velocity vectors (n_cells x n_dims).
    embedding : np.ndarray
        2D cell embedding (n_cells x 2).
    grid_size : int
        Number of grid points per dimension.
    smoothing : float
        Smoothing factor for grid interpolation.

    Returns
    -------
    Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]
        Grid X, Grid Y, velocity U, velocity V.
    """
    from scipy.interpolate import griddata

    x = embedding[:, 0]
    y = embedding[:, 1]
    u = velocity[:, 0]
    v = velocity[:, 1]

    xi = np.linspace(x.min() - 1, x.max() + 1, grid_size)
    yi = np.linspace(y.min() - 1, y.max() + 1, grid_size)
    Xi, Yi = np.meshgrid(xi, yi)

    Ui = griddata((x, y), u, (Xi, Yi), method="cubic", fill_value=0)
    Vi = griddata((x, y), v, (Xi, Yi), method="cubic", fill_value=0)

    mask = np.isnan(Ui)
    Ui[mask] = 0
    Vi[mask] = 0

    return Xi, Yi, Ui, Vi


def compute_velocity_confidence(
    velocity: np.ndarray,
    nfr_ratios: pd.Series,
    adj: csr_matrix,
) -> pd.Series:
    """
    Compute confidence score for each cell's velocity estimate.

    Confidence is based on the consistency of velocity direction
    with local NFR ratio gradient.

    Parameters
    ----------
    velocity : np.ndarray
        Velocity vectors (n_cells x n_dims).
    nfr_ratios : pd.Series
        Per-cell NFR ratios.
    adj : csr_matrix
        Adjacency matrix.

    Returns
    -------
    pd.Series
        Per-cell confidence scores (0-1).
    """
    n_cells = velocity.shape[0]
    confidence = np.zeros(n_cells)

    ratios = nfr_ratios.values.astype(np.float64)

    for i in range(n_cells):
        if issparse(adj):
            neighbors = adj[i].indices
            weights = adj[i].data
        else:
            neighbors = np.where(adj[i] > 0)[0]
            weights = adj[i][neighbors]

        if len(neighbors) == 0 or np.linalg.norm(velocity[i]) < 1e-8:
            continue

        ratio_gradient = ratios[neighbors] - ratios[i]
        expected_direction = np.sign(ratio_gradient)

        if issparse(adj):
            actual_direction = np.sign(
                (embedding[neighbors] - embedding[i]) @ velocity[i]
            )
        else:
            actual_direction = np.sign(
                (embedding[neighbors] - embedding[i]) @ velocity[i]
            )

        agreement = (expected_direction == actual_direction).mean()
        confidence[i] = agreement

    return pd.Series(confidence, index=nfr_ratios.index, name="velocity_confidence")


def compute_pseudotime_from_velocity(
    velocity: np.ndarray,
    adj: csr_matrix,
    root_cells: Optional[list] = None,
    max_steps: int = 100,
) -> pd.Series:
    """
    Compute pseudotime by integrating velocity vectors along the graph.

    Parameters
    ----------
    velocity : np.ndarray
        Velocity vectors (n_cells x n_dims).
    adj : csr_matrix
        Adjacency matrix.
    root_cells : list, optional
        Indices of root cells. If None, cells with lowest NFR ratio are used.
    max_steps : int
        Maximum integration steps.

    Returns
    -------
    pd.Series
        Per-cell pseudotime values.
    """
    n_cells = velocity.shape[0]
    pseudotime = np.full(n_cells, np.inf)

    if root_cells is None:
        root_cells = [0]

    for root in root_cells:
        pseudotime[root] = 0
        current = root
        visited = {current}

        for step in range(max_steps):
            if issparse(adj):
                neighbors = adj[current].indices
            else:
                neighbors = np.where(adj[current] > 0)[0]

            neighbors = [n for n in neighbors if n not in visited]
            if not neighbors:
                break

            velocities = np.array([
                np.dot(velocity[n], velocity[current])
                for n in neighbors
            ])

            next_cell = neighbors[np.argmax(velocities)]
            pseudotime[next_cell] = step + 1
            visited.add(next_cell)
            current = next_cell

    pseudotime[pseudotime == np.inf] = np.nan
    return pd.Series(pseudotime, name="velocity_pseudotime")
