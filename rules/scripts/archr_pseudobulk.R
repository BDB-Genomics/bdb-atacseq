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

# Use pre-generated bgzipped and indexed fragment files from chromap_align
# Resolve to absolute paths BEFORE setwd() changes the working directory
fragment_files <- normalizePath(unlist(snakemake@input[["fragments"]]), mustWork = TRUE)

# Set working directory to arrow_dir so that Arrow files are created inside it
dir.create(arrow_dir, showWarnings = FALSE, recursive = TRUE)
setwd(arrow_dir)

cat("Creating Arrow files from fragment files\n")
ArrowFiles <- createArrowFiles(
    inputFiles = fragment_files,
    sampleNames = samples_info$sample,
    minTSS = snakemake@params[["min_tss"]],
    minFrags = snakemake@params[["min_frags"]],
    addTileMat = TRUE,
    addGeneScoreMat = TRUE
)

cat("Arrow files created:", length(ArrowFiles), "\n")
cat("ArchR Arrow files creation complete\n")
