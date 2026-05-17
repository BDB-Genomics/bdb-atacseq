suppressPackageStartupMessages({
    library(ArchR)
})

addArchRThreads(threads=as.integer(snakemake@threads))
addArchRGenome("hg38")

cat("===========================================\n")
cat("ArchR: Creating Arrow Files\n")
cat("===========================================\n")

sample_sheet <- snakemake@input[["sample_sheet"]]
bam_files <- snakemake@input[["bam"]]
arrow_dir <- snakemake@output[["arrow_dir"]]

samples_info <- read.delim(sample_sheet, header=TRUE, sep="\t")

# Set working directory to arrow_dir so that Arrow files are created inside it
dir.create(arrow_dir, showWarnings = FALSE, recursive = TRUE)
setwd(arrow_dir)

cat("Creating Arrow files from BAMs\n")
ArrowFiles <- createArrowFiles(
    inputFiles = bam_files,
    sampleNames = samples_info$sample,
    filterTSS = snakemake@params[["min_tss"]],
    filterFrags = c(snakemake@params[["min_frags"]], snakemake@params[["max_frags"]]),
    addTileMat = TRUE,
    addGeneScoreMat = TRUE
)

cat("Arrow files created:", length(ArrowFiles), "\n")
cat("ArchR Arrow files creation complete\n")
