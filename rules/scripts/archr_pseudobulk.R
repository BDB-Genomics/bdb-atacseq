suppressPackageStartupMessages({
    library(ArchR)
    library(GenomicRanges)
    library(Rsamtools)
})

if (exists("snakemake") && length(snakemake@log) > 0) {
    dir.create(dirname(snakemake@log[[1]]), showWarnings = FALSE, recursive = TRUE)
    log_file <- file(snakemake@log[[1]], open = "wt")
    sink(log_file)
    sink(log_file, type = "message")
    on.exit({
        try(sink(type = "message"), silent = TRUE)
        try(sink(), silent = TRUE)
        close(log_file)
    }, add = TRUE)
}

# Force 1 thread in CI mode to avoid mclapply concurrency issues
threads <- as.integer(snakemake@threads)
if (isTRUE(snakemake@config[["ci_mode"]])) {
    threads <- 1
}
addArchRThreads(threads = threads)
addArchRLocking(locking = FALSE)

cat("===========================================\n")
cat("ArchR: Creating Arrow Files\n")
cat("===========================================\n")

sample_sheet <- snakemake@input[["sample_sheet"]]
bam_files    <- snakemake@input[["bam"]]
arrow_dir    <- snakemake@output[["arrow_dir"]]

samples_info <- read.delim(sample_sheet, header=TRUE, sep="\t")

# Resolve to absolute paths BEFORE setwd() changes the working directory
fragment_files <- normalizePath(unlist(snakemake@input[["fragments"]]), mustWork = TRUE)

# Read chromosome names and lengths from the BAM header (stable across all Rsamtools versions)
bam_file_abs <- normalizePath(unlist(snakemake@input[["bam"]])[1], mustWork = TRUE)
bam_header   <- scanBamHeader(bam_file_abs)[[1]]$targets   # named integer vector
frag_chroms  <- names(bam_header)                          # character vector of chrom names
frag_lengths <- as.integer(bam_header)                     # integer vector (positional, same order)
cat("BAM header chromosomes:", paste(frag_chroms, collapse=", "), "\n")

# ---------------------------------------------------------------------------
# Build annotations: determine if data matches full hg38 or synthetic test reference
# ---------------------------------------------------------------------------
chr1_idx <- which(frag_chroms == "chr1")
chr1_len <- if (length(chr1_idx) > 0) frag_lengths[chr1_idx[1]] else 0

is_ci <- isTRUE(snakemake@config[["ci_mode"]]) || (chr1_len > 0 && chr1_len < 10000000) || length(frag_chroms) < 5

have_hg38 <- FALSE

if (!is_ci) {
    try(addArchRGenome("hg38"), silent = TRUE)
    geneAnnotation   <- tryCatch(getGeneAnnotation(),   error = function(e) NULL)
    genomeAnnotation <- tryCatch(getGenomeAnnotation(), error = function(e) NULL)
    have_hg38 <- !is.null(geneAnnotation) && !is.null(genomeAnnotation)
}

if (!have_hg38) {
    cat("[INFO] Synthetic reference or CI mode detected — building custom synthetic annotation.\n")

    # Build SeqInfo from BAM header
    si <- Seqinfo(seqnames = frag_chroms, seqlengths = frag_lengths, genome = "testGenome")

    # Spread synthetic genes every 10 kb across each chromosome (positional indexing)
    gene_records <- lapply(seq_along(frag_chroms), function(i) {
        chr     <- frag_chroms[i]
        chr_len <- frag_lengths[i]   # positional — never NA
        if (chr_len < 11000) return(NULL)
        starts  <- seq(5000, chr_len - 6000, by = 10000)
        strands <- rep_len(c("+", "-"), length(starts))
        GRanges(
            seqnames = chr,
            ranges   = IRanges(start = starts, width = 3000),
            strand   = strands,
            symbol   = paste0("Gene_", chr, "_", seq_along(starts)),
            gene_id  = paste0("GENE", gsub("chr", "", chr), seq_along(starts))
        )
    })
    gene_records <- Filter(Negate(is.null), gene_records)
    genes_gr <- do.call(c, gene_records)
    seqinfo(genes_gr) <- si

    tss_gr <- promoters(genes_gr, upstream = 1, downstream = 1)

    exons_gr <- GRanges(
        seqnames = seqnames(genes_gr),
        ranges   = IRanges(start = start(genes_gr), width = 500),
        strand   = strand(genes_gr),
        symbol   = genes_gr$symbol,
        gene_id  = genes_gr$gene_id
    )
    seqinfo(exons_gr) <- si

    geneAnnotation <- createGeneAnnotation(
        genes = genes_gr,
        exons = exons_gr,
        TSS   = tss_gr
    )

    chromSizes_gr <- GRanges(
        seqnames = frag_chroms,
        ranges   = IRanges(start = 1L, end = as.integer(frag_lengths))
    )
    seqlengths(chromSizes_gr) <- frag_lengths

    genomeAnnotation <- SimpleList(
        genome     = "testGenome",
        chromSizes = chromSizes_gr,
        blacklist  = GRanges()
    )

    # Set ArchR global genome to custom testGenome so internal ArchR calls use this annotation
    ArchR:::.setArchRGenome("testGenome", geneAnnotation = geneAnnotation, genomeAnnotation = genomeAnnotation)
} else {
    cat("[INFO] Using hg38 gene/genome annotation.\n")
}

# Set working directory to arrow_dir so Arrow files are created inside it
dir.create(arrow_dir, showWarnings = FALSE, recursive = TRUE)
setwd(arrow_dir)

cat("Creating Arrow files from fragment files\n")
ArrowFiles <- createArrowFiles(
    inputFiles       = fragment_files,
    sampleNames      = samples_info$sample,
    geneAnnotation   = geneAnnotation,
    genomeAnnotation = genomeAnnotation,
    minTSS           = snakemake@params[["min_tss"]],
    minFrags         = snakemake@params[["min_frags"]],
    addTileMat       = TRUE,
    addGeneScoreMat  = TRUE
)

cat("Arrow files created:", length(ArrowFiles), "\n")

# Check if any .arrow files were actually produced
created_arrows <- list.files(".", pattern = "\\.arrow$", full.names = TRUE)
if (length(created_arrows) == 0) {
    # Print latest ArchR log file for debugging before stopping
    log_files <- list.files("ArchRLogs", pattern = "\\.log$", full.names = TRUE)
    if (length(log_files) > 0) {
        latest_log <- log_files[order(file.info(log_files)$mtime, decreasing = TRUE)][1]
        cat("\n=== ArchR Internal Log (", basename(latest_log), ") ===\n", sep = "")
        cat(readLines(latest_log), sep = "\n")
        cat("===========================================\n\n")
    }
    stop("[FATAL] createArrowFiles produced 0 Arrow files — all samples failed. See ArchR log printed above for details.")
}

cat("ArchR Arrow files creation complete\n")
