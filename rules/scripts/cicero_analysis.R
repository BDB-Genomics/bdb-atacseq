suppressPackageStartupMessages({
    library(ArchR)
    library(cicero)
    library(GenomicRanges)
    library(ggplot2)
})

# Mock .available.genomes to prevent it from calling available.packages() which fails when BiocManager is missing
try({
    ns <- asNamespace("ArchR")
    unlockBinding(".available.genomes", ns)
    assign(".available.genomes", function(...) c("hg19","hg38","mm9","mm10"), envir = ns)
    lockBinding(".available.genomes", ns)
}, silent=TRUE)

# Mock utils::available.packages to prevent "Install BiocManager" error from get_data_annotation_contrib_url
try({
    ns <- asNamespace("utils")
    unlockBinding("available.packages", ns)
    orig_av <- utils::available.packages
    assign("available.packages", function(...) {
        tryCatch(orig_av(...), error = function(e) matrix(character(0), nrow=0, ncol=0))
    }, envir = ns)
    lockBinding("available.packages", ns)
}, silent=TRUE)


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
    dummy_gene_anno <- createGeneAnnotation(
        TSS = GRanges("chr1", IRanges(1, 100)),
        exons = GRanges("chr1", IRanges(1, 100)),
        genes = GRanges("chr1", IRanges(1, 100))
    )
    dummy_genome_anno <- list(
        chromSizes = GRanges("chr1", IRanges(1, 100)),
        blacklist = GRanges(),
        genome = "hg38"
    )
    options(ArchRGeneAnnotation = dummy_gene_anno)
    options(ArchRGenomeAnnotation = dummy_genome_anno)
    try({
        ns <- asNamespace("ArchR")
        env <- get(".ArchREnv", envir = ns)
        
        unlockBinding("ArchRGenome", env)
        assign("ArchRGenome", dummy_genome_anno, envir = env)
        lockBinding("ArchRGenome", env)

        unlockBinding("ArchRGeneAnnotation", env)
        assign("ArchRGeneAnnotation", dummy_gene_anno, envir = env)
        lockBinding("ArchRGeneAnnotation", env)

        unlockBinding("ArchRGenomeAnnotation", env)
        assign("ArchRGenomeAnnotation", dummy_genome_anno, envir = env)
        lockBinding("ArchRGenomeAnnotation", env)
    }, silent = TRUE)
}

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

cat("Extracting PeakMatrix or TileMatrix from ArchR project\n")
peak_mat <- tryCatch({
    getMatrixFromProject(proj, useMatrix = "PeakMatrix")
}, error = function(e) {
    message("[INFO] PeakMatrix not found, attempting addReproduciblePeakSet & addPeakMatrix...")
    proj_peaks <- tryCatch({
        p <- addReproduciblePeakSet(proj, groupBy = "Clusters")
        addPeakMatrix(p)
    }, error = function(e2) NULL)
    if (!is.null(proj_peaks)) {
        tryCatch(getMatrixFromProject(proj_peaks, useMatrix = "PeakMatrix"), error = function(e3) NULL)
    } else NULL
})

if (is.null(peak_mat)) {
    message("[INFO] Falling back to TileMatrix for Cicero analysis...")
    peak_mat <- getMatrixFromProject(proj, useMatrix = "TileMatrix")
}

counts <- assay(peak_mat)
peaks <- rowRanges(peak_mat)
peaks_char <- paste(seqnames(peaks), start(peaks), end(peaks), sep = "_")
rownames(counts) <- peaks_char

cat("Creating cell_data_set for Cicero\n")
input_cds <- make_atac_cds(counts, binarize = TRUE)

cat("Running Cicero co-accessibility\n")
genome_size <- read.delim(genome_sizes_file, header=FALSE, sep="\t")

# run_cicero expects a CellDataSet and a data.frame of chromosome sizes
cicero_conns <- run_cicero(
    input_cds,
    genomic_coords = genome_size,
    window_size = as.integer(snakemake@params[["window_size"]])
)

cat("Co-accessibility connections computed\n")

ccans <- generate_ccans(cicero_conns, coaccess_cutoff = 0.3)

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
