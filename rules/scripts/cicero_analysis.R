suppressPackageStartupMessages({
    library(ArchR)
    library(cicero)
    library(monocle3)
    library(GenomicRanges)
    library(ggplot2)
})

addArchRThreads(threads=as.integer(snakemake@threads))
addArchRGenome("hg38")

cat("===========================================\n")
cat("Cicero: Co-accessibility Analysis\n")
cat("===========================================\n")

arrow_dir <- snakemake@input[["arrow_dir"]]
clusters_file <- snakemake@input[["clusters"]]
genome_sizes_file <- snakemake@input[["genome_sizes"]]
conn_net_out <- snakemake@output[["conn_net"]]
conn_df_out <- snakemake@output[["conn_df"]]
ccans_net_out <- snakemake@output[["ccans_net"]]
ccans_bed_out <- snakemake@output[["ccans_bed"]]
plot_out <- snakemake@output[["plot"]]

proj <- loadArchRProject(arrow_dir)

cat("Extracting PeakMatrix from ArchR project\n")
# PeakMatrix must exist or be calculated. We ensure PeakMatrix counts are fetched.
peak_mat <- getMatrixFromProject(proj, useMatrix = "PeakMatrix")
counts <- assay(peak_mat)
peaks <- rowRanges(peak_mat)
peaks_char <- paste(seqnames(peaks), start(peaks), end(peaks), sep = "_")
rownames(counts) <- peaks_char

cat("Creating cell_data_set for Cicero\n")
cell_metadata <- as.data.frame(getCellColData(proj))
feature_metadata <- data.frame(
    gene_short_name = peaks_char,
    row.names = peaks_char
)

cds <- new_cell_data_set(expression_data = counts,
                         cell_metadata = cell_metadata,
                         gene_metadata = feature_metadata)

cat("Running Cicero co-accessibility\n")
genome_size <- read.delim(genome_sizes_file, header=FALSE, sep="\t")

# run_cicero expects a CellDataSet and a data.frame of chromosome sizes
cicero_conns <- run_cicero(
    cds,
    genomic_coords = genome_size,
    window_size = as.integer(snakemake@params[["window_size"]])
)

cat("Co-accessibility connections computed\n")

ccans <- generate_ccans(cicero_conns, threshold = 0.3)

cat("CCANs generated\n")

saveRDS(cicero_conns, conn_net_out)
saveRDS(ccans, ccans_net_out)

conn_df <- as.data.frame(cicero_conns)
write.table(conn_df, conn_df_out, sep="\t", quote=FALSE, row.names=TRUE)

# CCANs is a data.frame mapping Peak coordinates to CCAN ID
# Parse the peak coordinate strings (e.g. "chr1_10000_10500") to output BED format
if (nrow(ccans) > 0) {
    peaks_split <- strsplit(as.character(ccans$Peak), "_")
    ccans_bed <- data.frame(
        chr = sapply(peaks_split, `[`, 1),
        start = as.integer(sapply(peaks_split, `[`, 2)) - 1,
        end = as.integer(sapply(peaks_split, `[`, 3)),
        name = paste0("CCAN_", ccans$CCAN),
        score = 1
    )
} else {
    ccans_bed <- data.frame(chr=character(), start=integer(), end=integer(), name=character(), score=integer())
}
write.table(ccans_bed, ccans_bed_out, sep="\t", quote=FALSE, row.names=FALSE, col.names=FALSE)

cat("Co-accessibility results saved\n")

pdf(plot_out, width=10, height=8)
p <- ggplot(conn_df, aes(x=coaccess, fill=coaccess > 0.3)) +
    geom_histogram(bins=100) +
    theme_bw() +
    labs(title="Cicero Co-accessibility Distribution",
         x="Co-accessibility Score", y="Count") +
    geom_vline(xintercept=0.3, linetype="dashed", color="red") +
    scale_fill_manual(values = c("TRUE" = "darkred", "FALSE" = "grey60"))
print(p)
dev.off()

cat("Co-accessibility plot saved\n")
cat("Cicero analysis complete\n")
