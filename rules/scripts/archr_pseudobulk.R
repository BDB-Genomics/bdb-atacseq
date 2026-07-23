suppressPackageStartupMessages({
    library(ArchR)
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
tryCatch({
    addArchRGenome("hg38")
}, error = function(e) {
    message("[WARNING] addArchRGenome failed: ", e$message)
})

cat("===========================================\n")
cat("ArchR: Creating Arrow Files\n")
cat("===========================================\n")

sample_sheet <- snakemake@input[["sample_sheet"]]
bam_files <- snakemake@input[["bam"]]
arrow_dir <- snakemake@output[["arrow_dir"]]

samples_info <- read.delim(sample_sheet, header=TRUE, sep="\t")

# Convert BAMs to fragment files (10x-format .tsv.gz) required by createArrowFiles
fragment_files <- vapply(seq_along(bam_files), function(i) {
    bam <- bam_files[[i]]
    frag <- file.path(arrow_dir, paste0(samples_info$sample[i], "_fragments.tsv.gz"))
    dir.create(dirname(frag), showWarnings=FALSE, recursive=TRUE)
    
    # Write to a temporary uncompressed file first
    temp_frag <- tempfile(pattern = "fragments_", tmpdir = arrow_dir)
    cmd <- paste(
        "sinto fragments -b", shQuote(bam),
        "-f", shQuote(temp_frag),
        "--collapse_within"
    )
    ret <- system(cmd)
    if (ret != 0) stop("sinto fragments failed for: ", bam)
    
    # Coordinate sort and compress using bgzip (which is required by tabix)
    cmd_sort <- paste(
        "LC_ALL=C sort -k1,1 -k2,2n -k3,3n", shQuote(temp_frag),
        "| bgzip -c >", shQuote(frag)
    )
    ret_sort <- system(cmd_sort)
    if (ret_sort != 0) stop("sorting/bgzip failed for: ", temp_frag)
    
    unlink(temp_frag)
    
    # Index the fragment file
    ret_tabix <- system(paste("tabix -p bed", shQuote(frag)))
    if (ret_tabix != 0) stop("tabix index generation failed for: ", frag)
    frag
}, character(1))

# Set working directory to arrow_dir so that Arrow files are created inside it
dir.create(arrow_dir, showWarnings = FALSE, recursive = TRUE)
setwd(arrow_dir)

cat("Creating Arrow files from fragment files\n")
ArrowFiles <- createArrowFiles(
    inputFiles = basename(fragment_files),
    sampleNames = samples_info$sample,
    filterTSS = snakemake@params[["min_tss"]],
    filterFrags = snakemake@params[["min_frags"]],
    addTileMat = TRUE,
    addGeneScoreMat = TRUE
)

cat("Arrow files created:", length(ArrowFiles), "\n")
cat("ArchR Arrow files creation complete\n")
