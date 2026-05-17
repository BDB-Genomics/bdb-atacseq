suppressPackageStartupMessages({
    library(ArchR)
    library(ggplot2)
})

addArchRThreads(threads=as.integer(snakemake@threads))
addArchRGenome("hg38")

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
    dimsToUse = seq(1, as.integer(snakemake@params[["dims_to_use"]])))

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

markerList <- getMarkers(markers, cutOff = "FDR <= 0.1 & Log2FC >= 0.5")

write.table(markerList$pos, markers_out, sep="\t", quote=FALSE, row.names=FALSE)

cat("Marker genes saved\n")

pdf(umap_out, width=10, height=8)
p1 <- plotEmbedding(ArchRProj=proj, color="Clusters", title="UMAP Clustering", pallete="Set3", size=0.1)
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
plotEmbedding(ArchRProj=proj, color="TSSEnrichment", title="TSS Enrichment", size=0.1)
plotEmbedding(ArchRProj=proj, color="log10(nFrags)", title="Log10 Fragments", size=0.1)
plotEmbedding(ArchRProj=proj, color="Clusters", title="Clusters", pallete="Set3", size=0.1)
dev.off()

cat("Full report saved\n")
cat("ArchR clustering complete\n")
