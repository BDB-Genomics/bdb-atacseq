suppressPackageStartupMessages({
    library(ArchR)
    library(ggplot2)
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

# Robustly set hg38 genome: try addArchRGenome first, fall back to bundled annotations
genome_set <- tryCatch({
    addArchRGenome("hg38")
    TRUE
}, error = function(e) {
    message("[WARNING] addArchRGenome failed (BSgenome/BiocManager unavailable): ", e$message)
    message("[INFO] Falling back to ArchR bundled hg38 annotations...")
    FALSE
})
if (!genome_set) {
    ArchR:::.setArchRGenome("hg38",
        geneAnnotation  = ArchR:::geneAnnoHg38,
        genomeAnnotation = ArchR:::genomeAnnoHg38)
}

cat("===========================================\n")
cat("ArchR: Clustering & Marker Identification\n")
cat("===========================================\n")

arrow_dir <- snakemake@input[["arrow_dir"]]
clusters_out <- snakemake@output[["clusters"]]
umap_out <- snakemake@output[["umap"]]
markers_out <- snakemake@output[["marker_genes"]]
full_report <- snakemake@output[["full_report"]]

proj <- loadArchRProject(arrow_dir)

cat("Running dimensionality reduction\n")
proj <- addIterativeLSI(
    ArchRProj = proj,
    useMatrix = "TileMatrix",
    name = "IterativeLSI",
    iterations = 2,
    scaleTo = 25000,
    dimsToUse = eval(parse(text = snakemake@params[["dims_to_use"]])))

proj <- addUMAP(
    ArchRProj = proj,
    reducedDims = "IterativeLSI",
    name = "UMAP",
    nNeighbors = 30,
    minDist = 0.5,
    metric = "cosine"
)

proj <- addClusters(
    input = proj,
    resolution = as.numeric(snakemake@params[["resolution"]]),
    method = "Seurat",
    reducedDims = "IterativeLSI"
)

cat("Clustering complete\n")

markers <- getMarkerFeatures(
    ArchRProj = proj,
    useMatrix = "GeneScoreMatrix",
    groupBy = "Clusters",
    bias = c("TSSEnrichment", "log10(nFrags)")
)

# getMarkers returns a named list keyed by cluster; combine all into one data.frame
markerDF <- do.call(rbind, lapply(names(markerList), function(cl) {
    df <- as.data.frame(markerList[[cl]])
    if (nrow(df) > 0) df$Cluster <- cl
    df
}))
write.table(markerDF, markers_out, sep="\t", quote=FALSE, row.names=FALSE)

cat("Marker genes saved\n")

pdf(umap_out, width=10, height=8)
p1 <- plotEmbedding(ArchRProj=proj, color="Clusters", title="UMAP Clustering", palette="Set3", size=0.1)
print(p1)
dev.off()

cat("UMAP plot saved\n")

clusters_df <- data.frame(
    Cell = proj$cellNames,
    Cluster = proj$Clusters,
    TSSEnrichment = proj$TSSEnrichment,
    nFrags = proj$nFrags
)
write.table(clusters_df, clusters_out, sep="\t", quote=FALSE, row.names=FALSE)

cat("Cell clusters saved\n")

pdf(full_report, width=14, height=10)
print(plotEmbedding(ArchRProj=proj, colorBy="cellColData", name="TSSEnrichment", title="TSS Enrichment", size=0.1))
print(plotEmbedding(ArchRProj=proj, colorBy="cellColData", name="nFrags", title="nFrags", size=0.1))
print(plotEmbedding(ArchRProj=proj, colorBy="cellColData", name="Clusters", title="Clusters", size=0.1))
dev.off()

cat("Full report saved\n")
cat("ArchR clustering complete\n")
