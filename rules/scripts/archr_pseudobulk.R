suppressPackageStartupMessages({
    library(ArchR)
    library(GenomicRanges)
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
# Build annotations: use hg38 if chromosomes match, else build from data
# ---------------------------------------------------------------------------
suppressPackageStartupMessages(library(Rsamtools))

# Peek at chromosomes and sizes in the first fragment file
tbi_path   <- paste0(fragment_files[1], ".tbi")
tbx        <- TabixFile(fragment_files[1])
frag_seqinfo <- seqinfo(tbx)
frag_chroms  <- seqnames(frag_seqinfo)
frag_lengths <- seqlengths(frag_seqinfo)
cat("Fragment file chromosomes:", paste(frag_chroms, collapse=", "), "\n")

# Try loading hg38 bundled annotations
hg38_gene_anno <- tryCatch({
    addArchRGenome("hg38")
    getGeneAnnotation()
}, error = function(e) {
    tryCatch(ArchR:::geneAnnoHg38, error = function(e2) NULL)
})
hg38_genome_anno <- tryCatch({
    getGenomeAnnotation()
}, error = function(e) {
    tryCatch(ArchR:::genomeAnnoHg38, error = function(e2) NULL)
})

# Check if any fragment chromosomes overlap hg38 gene annotation chromosomes
use_hg38 <- FALSE
if (!is.null(hg38_gene_anno)) {
    hg38_chroms <- as.character(unique(seqnames(hg38_gene_anno$genes)))
    overlap_chroms <- intersect(frag_chroms, hg38_chroms)
    if (length(overlap_chroms) > 0) {
        cat("[INFO] Fragment chroms overlap hg38 annotation — using hg38 annotations.\n")
        use_hg38 <- TRUE
        geneAnnotation  <- hg38_gene_anno
        genomeAnnotation <- hg38_genome_anno
    }
}

if (!use_hg38) {
    cat("[INFO] No overlap between fragment chroms and hg38 annotation.\n")
    cat("[INFO] Building minimal synthetic annotation from fragment seqinfo (CI/test mode).\n")

    # Build a synthetic SeqInfo for our small test genome
    si <- Seqinfo(seqnames = frag_chroms, seqlengths = frag_lengths, genome = "testGenome")

    # Spread synthetic genes every 10kb across each chromosome
    gene_records <- lapply(frag_chroms, function(chr) {
        chr_len <- frag_lengths[chr]
        starts  <- seq(5000, max(5000, chr_len - 6000), by = 10000)
        strands <- rep_len(c("+", "-"), length(starts))
        GRanges(
            seqnames = chr,
            ranges   = IRanges(start = starts, width = 3000),
            strand   = strands,
            symbol   = paste0("Gene_", chr, "_", seq_along(starts)),
            gene_id  = paste0("GENE", chr, seq_along(starts))
        )
    })
    genes_gr <- do.call(c, gene_records)
    seqinfo(genes_gr) <- si

    # TSS = start of each gene (adjusted for strand)
    tss_gr <- promoters(genes_gr, upstream = 1, downstream = 1)

    # Exons = first 500bp of each gene body
    exons_gr <- GRanges(
        seqnames = seqnames(genes_gr),
        ranges   = IRanges(start = start(genes_gr), width = 500),
        strand   = strand(genes_gr),
        symbol   = genes_gr$symbol,
        gene_id  = genes_gr$gene_id
    )
    seqinfo(exons_gr) <- si

    geneAnnotation <- createGeneAnnotation(
        genes  = genes_gr,
        exons  = exons_gr,
        TSS    = tss_gr
    )

    genomeAnnotation <- createGenomeAnnotation(
        genome    = si,
        chromSizes = data.frame(
            chr    = frag_chroms,
            start  = 1L,
            end    = as.integer(frag_lengths)
        ),
        blacklist = GRanges()   # no blacklist for test data
    )
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

