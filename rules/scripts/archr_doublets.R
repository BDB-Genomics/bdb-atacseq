suppressPackageStartupMessages({
    library(ArchR)
})

addArchRThreads(threads=as.integer(snakemake@threads))
addArchRGenome("hg38")

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

doubScores <- addDoubletScores(
    input = ArrowFiles,
    k = 10,
    knnMethod = "UMAP",
    LSIMethod = 1
)

cat("Doublet enrichment calculated\n")

proj <- ArchRProject(
    ArrowFiles = ArrowFiles,
    outputDirectory = filtered_arrow_dir,
    copyArrows = TRUE
)

proj <- filterDoublets(proj, cutEnrich = snakemake@params[["doublet_threshold"]])

cat("Doublets filtered\n")

pdf(doublet_report, width=10, height=8)
p <- plotEmbedding(proj, colorBy = "cellColData", name = "DoubletEnrichment")
print(p)
dev.off()

cat("Doublet report saved\n")
cat("Filtered Arrow files saved to:", filtered_arrow_dir, "\n")
