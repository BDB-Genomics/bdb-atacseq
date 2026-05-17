#!/usr/bin/env python3
"""
Tests for Chromatin Velocity module.

Run with: python -m pytest chromatin_velocity/tests/ -v
"""

import numpy as np
import pandas as pd
import pytest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parent.parent))

from chromatin_velocity.fragment_analysis import (
    classify_fragments,
    compute_nfr_ratio,
    compute_fragment_size_distribution,
    compute_nucleosome_periodicity,
)
from chromatin_velocity.velocity import (
    build_knn_graph,
    compute_velocity_vectors,
    project_velocity,
)


@pytest.fixture
def sample_fragments():
    """Create synthetic fragment data with known NFR/MonoNuc distribution."""
    np.random.seed(42)
    n_cells = 50

    fragments = []
    for i in range(n_cells):
        barcode = f"cell_{i:04d}"
        n_frags = np.random.randint(200, 500)

        for _ in range(n_frags):
            size = np.random.choice(
                [np.random.normal(80, 20), np.random.normal(200, 30)],
                p=[0.6, 0.4]
            )
            size = max(10, int(size))
            fragments.append((barcode, "chr1", 0, size, size))

    return pd.DataFrame(fragments, columns=["barcode", "chrom", "start", "end", "size"])


@pytest.fixture
def sample_embedding():
    """Create synthetic 2D embedding."""
    np.random.seed(42)
    n_cells = 50
    return np.random.randn(n_cells, 2)


def test_classify_fragments(sample_fragments):
    """Test fragment classification."""
    result = classify_fragments(sample_fragments)

    assert "class" in result.columns
    assert set(result["class"].unique()).issubset({"NFR", "MonoNuc"})
    assert (result.loc[result["size"] < 147, "class"] == "NFR").all()
    assert (result.loc[result["size"] >= 147, "class"] == "MonoNuc").all()


def test_compute_nfr_ratio(sample_fragments):
    """Test NFR ratio computation."""
    classified = classify_fragments(sample_fragments)
    ratios = compute_nfr_ratio(classified, groupby="barcode", min_fragments=100)

    assert "nfr_ratio" in ratios.columns
    assert "nfr_log_ratio" in ratios.columns
    assert (ratios["nfr_ratio"] >= 0).all()
    assert (ratios["nfr_ratio"] <= 1).all()
    assert len(ratios) > 0


def test_compute_fragment_size_distribution(sample_fragments):
    """Test fragment size distribution."""
    centers, counts = compute_fragment_size_distribution(sample_fragments)

    assert len(centers) == len(counts)
    assert counts.sum() == len(sample_fragments)
    assert centers.min() >= 0


def test_compute_nucleosome_periodicity():
    """Test nucleosome periodicity detection."""
    sizes = np.arange(0, 500)
    counts = np.zeros(500)

    counts[80:120] = 100
    counts[180:220] = 80
    counts[360:400] = 60

    repeat_length = compute_nucleosome_periodicity(sizes, counts)

    assert not np.isnan(repeat_length)
    assert 150 < repeat_length < 250


def test_build_knn_graph(sample_embedding):
    """Test KNN graph construction."""
    adj, distances, indices = build_knn_graph(sample_embedding, n_neighbors=10)

    assert adj.shape == (50, 50)
    assert distances.shape == (50, 10)
    assert indices.shape == (50, 10)


def test_compute_velocity_vectors(sample_fragments, sample_embedding):
    """Test velocity vector computation."""
    classified = classify_fragments(sample_fragments)
    ratios = compute_nfr_ratio(classified, groupby="barcode", min_fragments=100)

    if len(ratios) < 10:
        pytest.skip("Not enough cells with sufficient fragments")

    n_cells = min(len(ratios), sample_embedding.shape[0])
    ratio_series = ratios["nfr_ratio"].iloc[:n_cells]
    embedding = sample_embedding[:n_cells]

    adj = build_knn_graph(embedding, n_neighbors=min(10, n_cells - 1))[0]
    velocity = compute_velocity_vectors(ratio_series, embedding, adj=adj)

    assert velocity.shape == (n_cells, 2)
    assert not np.all(velocity == 0)


def test_project_velocity(sample_embedding):
    """Test velocity projection onto grid."""
    velocity = np.random.randn(50, 2)

    Xi, Yi, Ui, Vi = project_velocity(velocity, sample_embedding, grid_size=20)

    assert Xi.shape == (20, 20)
    assert Yi.shape == (20, 20)
    assert Ui.shape == (20, 20)
    assert Vi.shape == (20, 20)
    assert not np.all(np.isnan(Ui))


def test_nfr_ratio_edge_cases():
    """Test NFR ratio with edge cases."""
    df = pd.DataFrame({
        "barcode": ["cell_1"] * 100,
        "chrom": ["chr1"] * 100,
        "start": [0] * 100,
        "end": list(range(10, 110)),
        "size": list(range(10, 110)),
    })

    classified = classify_fragments(df)
    ratios = compute_nfr_ratio(classified, groupby="barcode", min_fragments=10)

    assert len(ratios) == 1
    expected_nfr = sum(1 for s in range(10, 110) if s < 147) / 100
    assert abs(ratios.iloc[0]["nfr_ratio"] - expected_nfr) < 0.01


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
