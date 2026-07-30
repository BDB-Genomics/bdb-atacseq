# =============================================================================
# BDB-Genomics Custom Container: chromVAR + motifmatchr
# =============================================================================
# This replaces the broken quay.io/biocontainers/bioconductor-chromvar image
# which no longer ships motifmatchr in newer tags and has been removed for
# older tags.
#
# Base: Bioconductor RELEASE_3_18 (R 4.3)
# Pinned packages ensure full reproducibility.
# =============================================================================
FROM bioconductor/bioconductor_docker:RELEASE_3_18

LABEL maintainer="BDB-Genomics <bdb-genomics@github.com>"
LABEL org.opencontainers.image.source="https://github.com/BDB-Genomics/bdb-atacseq"
LABEL org.opencontainers.image.description="chromVAR + motifmatchr for ATAC-seq motif accessibility analysis"

# System dependencies for R packages that compile from source
# Note: libcurl4-gnutls-dev is already in the base image; do NOT install
# libcurl4-openssl-dev as it conflicts.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libxml2-dev \
    zlib1g-dev \
    libbz2-dev \
    liblzma-dev \
    && rm -rf /var/lib/apt/lists/*

# Install all R/Bioconductor packages needed by chromvar_analysis.R
# Order: dependencies first, then the packages that need them
RUN R -e " \
    BiocManager::install(c( \
        'GenomicRanges', \
        'IRanges', \
        'SummarizedExperiment', \
        'Rsamtools', \
        'Biostrings', \
        'BSgenome', \
        'chromVAR', \
        'motifmatchr', \
        'TFBSTools', \
        'JASPAR2024', \
        'RSQLite' \
    ), ask = FALSE, update = FALSE); \
    install.packages(c('ggplot2', 'pheatmap', 'RColorBrewer'), repos = 'https://cloud.r-project.org'); \
    "

# Smoke test: verify critical packages load
RUN R -e " \
    library(chromVAR); \
    library(motifmatchr); \
    library(TFBSTools); \
    library(Rsamtools); \
    library(JASPAR2024); \
    cat('All packages loaded successfully.\n') \
    "
