suppressPackageStartupMessages({
    library(DESeq2)
    library(ggplot2)
    library(pheatmap)
    library(RColorBrewer)
})

dir.create(dirname(snakemake@log[[1]]), recursive = TRUE, showWarnings = FALSE)
log_file <- file(snakemake@log[[1]], open = "wt")
sink(log_file)
sink(log_file, type = "message")
on.exit({
    try(sink(type = "message"), silent = TRUE)
    try(sink(), silent = TRUE)
    close(log_file)
}, add = TRUE)


safe_transform <- function(dds) {
    tryCatch(
        vst(dds, blind = FALSE),
        error = function(e) {
            cat("vst() failed, falling back to varianceStabilizingTransformation():\n")
            cat(conditionMessage(e), "\n")
            varianceStabilizingTransformation(dds, blind = FALSE)
        }
    )
}


cat("===========================================\n")
cat("Differential Accessibility Analysis\n")
cat("===========================================\n")

sample_sheet <- snakemake@input[["sample_sheet"]]
count_files <- snakemake@input[["counts"]]
output_results <- snakemake@output[["results"]]
output_volcano <- snakemake@output[["plot_volcano"]]
output_ma <- snakemake@output[["plot_ma"]]
output_heatmap <- snakemake@output[["plot_heatmap"]]
output_pca <- snakemake@output[["plot_pca"]]
fdr_threshold <- as.numeric(snakemake@params[["fdr_threshold"]])
log2fc_threshold <- as.numeric(snakemake@params[["log2fc_threshold"]])

output_dirs <- unique(dirname(c(output_results, output_volcano, output_ma, output_heatmap, output_pca)))
for (out_dir in output_dirs) {
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
}

run_analysis <- function() {
    cat("Loading sample sheet:", sample_sheet, "\n")
    samples_info <- read.delim(sample_sheet, header = TRUE, sep = "\t")

    cat("Building count matrix from", length(count_files), "files\n")

    peak_regions <- NULL
    list_of_counts <- list()

    for (cf in count_files) {
        sample_name <- gsub("_peak_counts.tsv$", "", basename(cf))
        df <- read.delim(cf, header = FALSE, sep = "\t",
                         col.names = c("chr", "start", "end", "count"))

        if (is.null(peak_regions)) {
            peak_regions <- paste(df$chr, df$start, df$end, sep = "_")
        }

        list_of_counts[[sample_name]] <- df$count
    }

    if (is.null(peak_regions) || length(peak_regions) < 10) {
        stop("Too few peaks found for DESeq2 differential accessibility analysis.")
    }

    count_matrix <- as.data.frame(do.call(cbind, list_of_counts))
    rownames(count_matrix) <- peak_regions

    cat("Count matrix:", nrow(count_matrix), "peaks x", ncol(count_matrix), "samples\n")

    cat("Creating sample metadata\n")
    condition_col <- if ("condition" %in% colnames(samples_info)) "condition" else "group"
    coldata <- samples_info[match(colnames(count_matrix), samples_info$sample), ]
    rownames(coldata) <- coldata$sample
    coldata <- data.frame(
        row.names = coldata$sample,
        condition = coldata[[condition_col]],
        replicate = coldata$replicate
    )

    cat("Conditions:", paste(unique(coldata$condition), collapse = ", "), "\n")
    cat("Running DESeq2\n")

    dds <- DESeqDataSetFromMatrix(
        countData = count_matrix,
        colData = coldata,
        design = ~ condition
    )

    dds <- DESeq(dds, quiet = TRUE)

    cat("Extracting results\n")
    res <- results(dds, alpha = fdr_threshold)
    res <- res[order(res$padj), ]

    res_df <- as.data.frame(res)
    res_df$peak <- rownames(res_df)
    res_df$significant <- ifelse(
        res_df$padj < fdr_threshold & abs(res_df$log2FoldChange) > log2fc_threshold,
        "Yes", "No"
    )

    write.table(res_df, output_results, sep = "\t", quote = FALSE, row.names = FALSE)

    sig_peaks <- sum(res_df$significant == "Yes", na.rm = TRUE)
    cat("Significant peaks (FDR <", fdr_threshold, ", |log2FC| >", log2fc_threshold, "):", sig_peaks, "\n")

    cat("Generating plots\n")

    pdf(output_volcano, width = 10, height = 8)
    print(
        ggplot(res_df, aes(x = log2FoldChange, y = -log10(padj), color = significant)) +
            geom_point(alpha = 0.6, size = 1.5) +
            scale_color_manual(values = c("No" = "gray70", "Yes" = "red")) +
            geom_hline(yintercept = -log10(fdr_threshold), linetype = "dashed", color = "blue") +
            geom_vline(xintercept = c(-log2fc_threshold, log2fc_threshold), linetype = "dashed", color = "blue") +
            labs(title = "Differential Accessibility - Volcano Plot",
                 x = "Log2 Fold Change", y = "-Log10 Adjusted P-value") +
            theme_bw(base_size = 14) +
            theme(legend.position = "bottom")
    )
    dev.off()
    cat("  Volcano plot saved\n")

    pdf(output_ma, width = 10, height = 8)
    print(
        ggplot(res_df, aes(x = baseMean, y = log2FoldChange, color = significant)) +
            geom_point(alpha = 0.6, size = 1.5) +
            scale_x_log10() +
            scale_color_manual(values = c("No" = "gray70", "Yes" = "red")) +
            geom_hline(yintercept = 0, linetype = "dashed", color = "blue") +
            labs(title = "Differential Accessibility - MA Plot",
                 x = "Mean Normalized Counts", y = "Log2 Fold Change") +
            theme_bw(base_size = 14) +
            theme(legend.position = "bottom")
    )
    dev.off()
    cat("  MA plot saved\n")

    vst_counts <- safe_transform(dds)
    vsd_mat <- assay(vst_counts)

    pdf(output_pca, width = 10, height = 8)
    pca_data <- plotPCA(vst_counts, intgroup = "condition", returnData = TRUE)
    percentVar <- round(100 * attr(pca_data, "percentVar"))
    print(
        ggplot(pca_data, aes(PC1, PC2, color = condition)) +
            geom_point(size = 4) +
            labs(title = "PCA Plot - Variance Stabilized Counts",
                 x = paste0("PC1: ", percentVar[1], "% variance"),
                 y = paste0("PC2: ", percentVar[2], "% variance")) +
            theme_bw(base_size = 14) +
            theme(legend.position = "bottom")
    )
    dev.off()
    cat("  PCA plot saved\n")

    top_n <- min(50, nrow(res_df))
    top_genes <- head(rownames(res_df[!is.na(res_df$padj), ]), top_n)
    top_mat <- vsd_mat[top_genes, , drop = FALSE]

    pdf(output_heatmap, width = 10, height = 12)
    if (is.matrix(top_mat) && nrow(top_mat) >= 2) {
        pheatmap(
            top_mat,
            annotation_col = coldata[, "condition", drop = FALSE],
            scale = "row",
            clustering_distance_rows = "correlation",
            clustering_distance_cols = "correlation",
            main = "Top Differentially Accessible Regions",
            color = colorRampPalette(rev(brewer.pal(9, "RdBu")))(100)
        )
    } else {
        plot.new()
        text(0.5, 0.5, "Not enough significant regions for heatmap (>1 required)")
    }
    dev.off()
    cat("  Heatmap saved\n")

    cat("===========================================\n")
    cat("Differential Accessibility Analysis Complete!\n")
    cat("Results:", output_results, "\n")
    cat("===========================================\n")
}

run_analysis()
