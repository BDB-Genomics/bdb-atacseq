suppressPackageStartupMessages({
    library(chromVAR)
    library(BSgenome)
    library(TFBSTools)
    library(JASPAR2024)
    library(ggplot2)
    library(pheatmap)
    library(RColorBrewer)
})

cat("===========================================\n")
cat("chromVAR Motif Accessibility Analysis\n")
cat("===========================================\n")

bam_file <- snakemake@input[["shifted_bam"]]
peak_file <- snakemake@input[["peaks"]]
motif_db <- snakemake@input[["motif_db"]]
genome_fa <- snakemake@params[["genome"]]
genome_sizes <- snakemake@params[["genome_sizes"]]
output_deviations <- snakemake@output[["deviations"]]
output_bias <- snakemake@output[["bias_corrected"]]
output_plot <- snakemake@output[["plot"]]
sample_name <- snakemake@wildcards[["sample"]]

cat("Sample:", sample_name, "\n")
cat("Loading peaks:", peak_file, "\n")

# Read and resize peaks to 500bp (chromVAR standard)
peaks <- read.table(peak_file, header=FALSE, sep="\t")
gr_peaks <- GRanges(seqnames=peaks$V1,
                    ranges=IRanges(start=peaks$V2, end=peaks$V3))
gr_peaks <- resize(gr_peaks, width=500, fix="center")

# Unconditionally use custom FASTA file
cat("Using custom FASTA file:", genome_fa, "\n")
library(Rsamtools)
genome_obj <- FaFile(genome_fa)

cat("Computing GC bias and fragment counts from BAM\n")
# chromVAR getCounts expects: bamfile, peaks, paired=TRUE
counts <- getCounts(bam_file, gr_peaks, paired=TRUE)

cat("Adding GC bias\n")
counts <- addGCBias(counts, genome = genome_obj)

cat("Loading motif database\n")
pfm_list <- getMatrixSet(JASPAR2024, opts=list(species=9606, collection="CORE"))

cat("Matching motifs to peaks\n")
motif_ix <- matchMotifs(pfm_list, counts, genome = genome_obj)

cat("Computing deviations\n")
dev <- computeDeviations(
    object = counts,
    annotations = motif_ix
)

dev_scores <- deviationScores(dev)
raw_dev <- deviations(dev)

# Save results
write.table(dev_scores, output_deviations, sep="\t", quote=FALSE, col.names=NA)
write.table(raw_dev, output_bias, sep="\t", quote=FALSE, col.names=NA)

cat("Generating chromVAR plot\n")
# Filter out any motifs with NA values or zero variance
valid_rows <- apply(dev_scores, 1, function(x) !any(is.na(x)) && sd(x) > 0)
if (sum(valid_rows) >= 2) {
    deviations_filtered <- dev_scores[valid_rows, , drop=FALSE]
    top_n <- min(20, nrow(deviations_filtered))
    top_motifs <- head(rownames(deviations_filtered)[order(apply(deviations_filtered, 1, sd), decreasing=TRUE)], top_n)
    
    pdf(output_plot, width=12, height=10)
    pheatmap(deviations_filtered[top_motifs, , drop=FALSE],
             scale="row",
             clustering_distance_rows="correlation",
             clustering_distance_cols="correlation",
             main=paste0(sample_name, " - Top Variable Motifs"),
             color=colorRampPalette(rev(brewer.pal(9, "RdBu")))(100))
    dev.off()
    cat("  chromVAR plot saved\n")
} else {
    # Create empty PDF dummy if not enough variable motifs (e.g. single sample)
    pdf(output_plot, width=6, height=6)
    plot.new()
    text(0.5, 0.5, "Insufficient variance across motifs\nfor heatmap plotting")
    dev.off()
    cat("  chromVAR dummy plot saved (insufficient variance)\n")
}

cat("chromVAR analysis complete for", sample_name, "\n")
cat("===========================================\n")
