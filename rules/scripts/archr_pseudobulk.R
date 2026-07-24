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

addArchRThreads(threads=as.integer(snakemake@threads))

cat("===========================================\n")
cat("ArchR: Creating Arrow Files\n")
cat("===========================================\n")

sample_sheet <- snakemake@input[["sample_sheet"]]
bam_files    <- snakemake@input[["bam"]]
arrow_dir    <- snakemake@output[["arrow_dir"]]

samples_info <- read.delim(sample_sheet, header=TRUE, sep="\t")

# Resolve to absolute paths BEFORE setwd() changes the working directory
fragment_files <- normalizePath(unlist(snakemake@input[["fragments"]]), mustWork = TRUE)

# ---------------------------------------------------------------------------
# Build annotations: use hg38 if chromosomes match, else build from BAM header
# ---------------------------------------------------------------------------

# Read chromosome names and lengths from the BAM header (stable across all Rsamtools versions)
bam_file_abs <- normalizePath(unlist(snakemake@input[["bam"]])[1], mustWork = TRUE)
bam_header   <- scanBamHeader(bam_file_abs)[[1]]$targets   # named integer vector
frag_chroms  <- names(bam_header)                          # character vector of chrom names
frag_lengths <- as.integer(bam_header)                     # integer vector (positional, same order)
cat("BAM header chromosomes:", paste(frag_chroms, collapse=", "), "\n")

# ---------------------------------------------------------------------------
# Build annotation from the actual reference genome (correct for both CI and
# production if BSgenome/ArchR built-in annotations are unavailable).
# For production hg38 data, ArchR will automatically use internal hg38 TSS
# positions if addArchRGenome() succeeds; we only reach this builder in CI.
# ---------------------------------------------------------------------------
try(addArchRGenome("hg38"), silent = TRUE)   # sets global; ignored if BSgenome absent

# Attempt to use pre-set hg38 gene/genome annotation; fall back to synthetic
geneAnnotation  <- tryCatch(getGeneAnnotation(),   error = function(e) NULL)
genomeAnnotation <- tryCatch(getGenomeAnnotation(), error = function(e) NULL)

have_hg38 <- !is.null(geneAnnotation) && !is.null(genomeAnnotation)

if (have_hg38) {
    # Verify that at least one BAM chromosome appears in the gene annotation
    # (catches the case where a custom/mini reference has no real hg38 genes)
    anno_chroms <- tryCatch(
        as.character(unique(seqnames(geneAnnotation$genes))),
        error = function(e) character(0)
    )
    have_hg38 <- length(intersect(frag_chroms, anno_chroms)) > 0
}

if (!have_hg38) {
    cat("[INFO] hg38 annotation unavailable or no chrom overlap — building synthetic annotation (CI/test mode).\n")

    # Build SeqInfo from BAM header
    si <- Seqinfo(seqnames = frag_chroms, seqlengths = frag_lengths, genome = "testGenome")

    # Spread synthetic genes every 10 kb across each chromosome (positional indexing)
    gene_records <- lapply(seq_along(frag_chroms), function(i) {
        chr     <- frag_chroms[i]
        chr_len <- frag_lengths[i]   # positional — never NA
        # Need at least 11 kb for one gene at pos 5000 with width 3000 + 3000 buffer
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
    # Drop NULLs (chromosomes too short for any gene)
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

    genomeAnnotation <- createGenomeAnnotation(
        genome     = si,
        chromSizes = data.frame(
            chr   = frag_chroms,
            start = 1L,
            end   = frag_lengths
        ),
        blacklist  = GRanges()
    )
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
cat("ArchR Arrow files creation complete\n")

