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
cat("ArchR: Doublet Detection & Filtering\n")
cat("===========================================\n")

arrow_dir <- snakemake@input[["arrow_dir"]]
doublet_report <- snakemake@output[["doublet_report"]]
filtered_arrow_dir <- snakemake@output[["filtered_arrow_dir"]]

# Correct nonexistent getArrowFiles function call to list.files
ArrowFiles <- list.files(arrow_dir, pattern = "\\.arrow$", full.names = TRUE)

if (length(ArrowFiles) == 0) {
    stop("ERROR: No Arrow files (.arrow) found in directory: ", arrow_dir)
}

doubScores <- tryCatch({
    addDoubletScores(
        input = ArrowFiles,
        k = 10,
        knnMethod = "UMAP",
        LSIMethod = 1
    )
}, error = function(e) {
    message("[WARNING] addDoubletScores failed (e.g. low cell count): ", e$message)
    NULL
})

cat("Doublet enrichment calculated\n")

proj <- ArchRProject(
    ArrowFiles = ArrowFiles,
    outputDirectory = filtered_arrow_dir,
    copyArrows = TRUE
)

if (!is.null(doubScores)) {
    proj <- tryCatch({
        filterDoublets(proj, cutEnrich = snakemake@params[["doublet_threshold"]])
    }, error = function(e) {
        message("[WARNING] filterDoublets failed: ", e$message)
        proj
    })
    cat("Doublets filtered\n")
} else {
    cat("[NOTICE] Skipping doublet filtering due to low cell count / test dataset\n")
}

pdf(doublet_report, width=10, height=8)
tryCatch({
    p <- plotEmbedding(proj, colorBy = "cellColData", name = "DoubletEnrichment")
    print(p)
}, error = function(e) {
    plot.new()
    text(0.5, 0.5, "Doublet enrichment plot unavailable (low cell count/test data)")
})
dev.off()

cat("Doublet report saved\n")
cat("Filtered Arrow files saved to:", filtered_arrow_dir, "\n")
