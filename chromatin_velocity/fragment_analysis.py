"""
Fragment size analysis for Chromatin Velocity.

Extracts fragment sizes from BAM or fragment files, classifies them into
nucleosome-free (NFR) and mononucleosomal (MonoNuc) categories, and computes
per-cell and per-region NFR ratios.
"""

import numpy as np
import pandas as pd
from typing import Optional, Tuple, Dict, Union
from pathlib import Path
import logging

logger = logging.getLogger(__name__)

NFR_THRESHOLD = 147  # bp: fragments < 147 are nucleosome-free


def extract_fragment_sizes(
    fragment_file: Union[str, Path],
    cell_barcode_file: Optional[Union[str, Path]] = None,
    min_size: int = 10,
    max_size: int = 1000,
) -> pd.DataFrame:
    """
    Extract fragment sizes from a 10x-style fragment file or BED file.

    Parameters
    ----------
    fragment_file : str or Path
        Path to fragment file (tsv.gz or bed format).
        Expected columns: chrom, start, end, barcode, duplicate_count
    cell_barcode_file : str or Path, optional
        Path to file with valid cell barcodes (one per line).
        If None, all barcodes in fragment file are used.
    min_size : int
        Minimum fragment size to include (bp).
    max_size : int
        Maximum fragment size to include (bp).

    Returns
    -------
    pd.DataFrame
        DataFrame with columns: barcode, chrom, start, end, size
    """
    fragment_file = Path(fragment_file)
    logger.info(f"Reading fragment file: {fragment_file}")

    if fragment_file.suffix == ".gz":
        import gzip
        opener = lambda f: gzip.open(f, "rt")
    else:
        opener = lambda f: open(f, "r")

    valid_barcodes = None
    if cell_barcode_file is not None:
        with open(cell_barcode_file) as f:
            valid_barcodes = set(line.strip() for line in f if line.strip())
        logger.info(f"Loaded {len(valid_barcodes)} valid cell barcodes")

    fragments = []
    with opener(fragment_file) as f:
        for line in f:
            if line.startswith("#") or line.startswith("track"):
                continue
            parts = line.strip().split("\t")
            if len(parts) < 4:
                continue

            chrom, start, end, barcode = parts[0], int(parts[1]), int(parts[2]), parts[3]
            size = end - start

            if size < min_size or size > max_size:
                continue
            if valid_barcodes is not None and barcode not in valid_barcodes:
                continue

            fragments.append((barcode, chrom, start, end, size))

    df = pd.DataFrame(fragments, columns=["barcode", "chrom", "start", "end", "size"])
    logger.info(f"Extracted {len(df)} fragments for {df['barcode'].nunique()} cells")
    return df


def extract_fragment_sizes_from_bam(
    bam_file: Union[str, Path],
    barcode_tag: str = "CB",
    min_size: int = 10,
    max_size: int = 1000,
    min_mapq: int = 30,
) -> pd.DataFrame:
    """
    Extract fragment sizes from a BAM file with cell barcode tags.

    Parameters
    ----------
    bam_file : str or Path
        Path to BAM file (must be sorted and indexed).
    barcode_tag : str
        SAM tag containing cell barcode (default: "CB" for 10x).
    min_size : int
        Minimum fragment size to include (bp).
    max_size : int
        Maximum fragment size to include (bp).
    min_mapq : int
        Minimum mapping quality.

    Returns
    -------
    pd.DataFrame
        DataFrame with columns: barcode, chrom, start, end, size
    """
    try:
        import pysam
    except ImportError:
        raise ImportError("pysam is required for BAM extraction. Install with: pip install pysam")

    bam_file = Path(bam_file)
    logger.info(f"Reading BAM file: {bam_file}")

    fragments = []
    with pysam.AlignmentFile(str(bam_file), "rb") as bam:
        for read in bam.fetch():
            if read.is_unmapped or read.is_duplicate or read.is_secondary:
                continue
            if read.mapping_quality < min_mapq:
                continue

            barcode = read.get_tag(barcode_tag) if read.has_tag(barcode_tag) else None
            if barcode is None:
                continue

            if read.is_proper_pair and read.is_read1:
                size = abs(read.template_length)
                if min_size <= size <= max_size:
                    chrom = bam.get_reference_name(read.reference_id)
                    start = min(read.reference_start, read.next_reference_start)
                    end = start + size
                    fragments.append((barcode, chrom, start, end, size))

    df = pd.DataFrame(fragments, columns=["barcode", "chrom", "start", "end", "size"])
    logger.info(f"Extracted {len(df)} fragments for {df['barcode'].nunique()} cells")
    return df


def classify_fragments(
    df: pd.DataFrame,
    threshold: int = NFR_THRESHOLD,
) -> pd.DataFrame:
    """
    Classify fragments as nucleosome-free (NFR) or mononucleosomal (MonoNuc).

    Parameters
    ----------
    df : pd.DataFrame
        DataFrame with 'size' column.
    threshold : int
        Fragment size threshold (default: 147 bp).

    Returns
    -------
    pd.DataFrame
        Input DataFrame with added 'class' column ('NFR' or 'MonoNuc').
    """
    df = df.copy()
    df["class"] = np.where(df["size"] < threshold, "NFR", "MonoNuc")

    nfr_count = (df["class"] == "NFR").sum()
    mononuc_count = (df["class"] == "MonoNuc").sum()
    logger.info(f"Classified fragments: {nfr_count} NFR, {mononuc_count} MonoNuc")

    return df


def compute_nfr_ratio(
    df: pd.DataFrame,
    groupby: str = "barcode",
    min_fragments: int = 100,
) -> pd.DataFrame:
    """
    Compute per-cell (or per-group) NFR ratio.

    NFR ratio = NFR fragments / (NFR fragments + MonoNuc fragments)

    Parameters
    ----------
    df : pd.DataFrame
        DataFrame with 'class' and groupby columns.
    groupby : str
        Column to group by (default: 'barcode' for per-cell).
    min_fragments : int
        Minimum total fragments required for a cell to be included.

    Returns
    -------
    pd.DataFrame
        DataFrame with columns: {groupby}, nfr_count, mononuc_count,
        total_fragments, nfr_ratio, nfr_log_ratio
    """
    if "class" not in df.columns:
        df = classify_fragments(df)

    grouped = df.groupby([groupby, "class"]).size().unstack(fill_value=0)

    if "NFR" not in grouped.columns:
        grouped["NFR"] = 0
    if "MonoNuc" not in grouped.columns:
        grouped["MonoNuc"] = 0

    result = pd.DataFrame({
        "nfr_count": grouped["NFR"],
        "mononuc_count": grouped["MonoNuc"],
        "total_fragments": grouped["NFR"] + grouped["MonoNuc"],
    })

    result = result[result["total_fragments"] >= min_fragments].copy()

    result["nfr_ratio"] = result["nfr_count"] / result["total_fragments"]
    result["nfr_log_ratio"] = np.log2(
        (result["nfr_count"] + 1) / (result["mononuc_count"] + 1)
    )

    logger.info(f"Computed NFR ratios for {len(result)} cells (min {min_fragments} fragments)")
    return result


def compute_region_nfr_ratio(
    df: pd.DataFrame,
    regions: pd.DataFrame,
    min_fragments: int = 10,
) -> pd.DataFrame:
    """
    Compute NFR ratio for specific genomic regions (e.g., peaks, promoters).

    Parameters
    ----------
    df : pd.DataFrame
        DataFrame with columns: chrom, start, end, size, class.
    regions : pd.DataFrame
        DataFrame with columns: chrom, start, end, [name].
    min_fragments : int
        Minimum fragments overlapping a region to include it.

    Returns
    -------
    pd.DataFrame
        DataFrame with region-level NFR statistics.
    """
    if "class" not in df.columns:
        df = classify_fragments(df)

    try:
        import pyranges as pr
    except ImportError:
        raise ImportError("pyranges is required for region analysis. Install with: pip install pyranges")

    frag_gr = pr.PyRanges(df[["chrom", "start", "end", "size", "class"]])
    region_gr = pr.PyRanges(regions[["chrom", "start", "end"]])

    overlaps = frag_gr.join(region_gr, how="left")

    if "name" in regions.columns:
        group_col = ["Start_b", "End_b", "name"]
    else:
        group_col = ["Start_b", "End_b"]

    grouped = overlaps.df.groupby(group_col + ["class"]).size().unstack(fill_value=0)

    if "NFR" not in grouped.columns:
        grouped["NFR"] = 0
    if "MonoNuc" not in grouped.columns:
        grouped["MonoNuc"] = 0

    result = pd.DataFrame({
        "nfr_count": grouped["NFR"],
        "mononuc_count": grouped["MonoNuc"],
        "total_fragments": grouped["NFR"] + grouped["MonoNuc"],
    })

    result = result[result["total_fragments"] >= min_fragments].copy()
    result["nfr_ratio"] = result["nfr_count"] / result["total_fragments"]

    logger.info(f"Computed region NFR ratios for {len(result)} regions")
    return result


def compute_fragment_size_distribution(
    df: pd.DataFrame,
    bins: np.ndarray = None,
) -> Tuple[np.ndarray, np.ndarray]:
    """
    Compute genome-wide fragment size distribution.

    Parameters
    ----------
    df : pd.DataFrame
        DataFrame with 'size' column.
    bins : np.ndarray, optional
        Bin edges for histogram. Default: 0-500bp in 1bp bins.

    Returns
    -------
    Tuple[np.ndarray, np.ndarray]
        Bin centers and counts.
    """
    if bins is None:
        bins = np.arange(0, 501, 1)

    counts, edges = np.histogram(df["size"], bins=bins)
    centers = (edges[:-1] + edges[1:]) / 2

    return centers, counts


def compute_nucleosome_periodicity(
    centers: np.ndarray,
    counts: np.ndarray,
    min_size: int = 147,
    max_size: int = 500,
) -> float:
    """
    Estimate nucleosome repeat length from fragment size distribution.

    Uses autocorrelation to find the periodicity in the mononucleosomal
    and oligonucleosomal fragment sizes.

    Parameters
    ----------
    centers : np.ndarray
        Fragment size bin centers.
    counts : np.ndarray
        Fragment size counts.
    min_size : int
        Minimum size to consider for periodicity.
    max_size : int
        Maximum size to consider.

    Returns
    -------
    float
        Estimated nucleosome repeat length (bp).
    """
    mask = (centers >= min_size) & (centers <= max_size)
    signal = counts[mask]

    if len(signal) < 20:
        logger.warning("Insufficient signal for periodicity estimation")
        return np.nan

    signal = signal - np.mean(signal)
    autocorr = np.correlate(signal, signal, mode="full")
    autocorr = autocorr[len(autocorr) // 2:]

    peaks = np.where(
        (autocorr[1:-1] > autocorr[:-2]) & (autocorr[1:-1] > autocorr[2:])
    )[0] + 1

    if len(peaks) == 0:
        return np.nan

    first_peak_idx = peaks[0]
    repeat_length = centers[mask][0] + first_peak_idx

    logger.info(f"Estimated nucleosome repeat length: {repeat_length:.0f} bp")
    return repeat_length
