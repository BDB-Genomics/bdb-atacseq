import re

replacements = {
    r'"results/fastp"': r'"results/preprocessing/fastp"',
    r'"results/fastqc"': r'"results/preprocessing/fastqc"',
    r'"results/bowtie2"': r'"results/alignment/bowtie2"',
    r'"results/samtools_sort"': r'"results/post_alignment/samtools_sort"',
    r'"results/mito-ATAC"': r'"results/post_alignment/mito-ATAC"',
    r'"results/remove_mito_reads"': r'"results/post_alignment/remove_mito_reads"',
    r'"results/samtools_index"': r'"results/post_alignment/samtools_index"',
    r'"results/samtools_fixmate"': r'"results/post_alignment/samtools_fixmate"',
    r'"results/samtools_markdup"': r'"results/post_alignment/samtools_markdup"',
    r'"results/samtools_index/post_markdup"': r'"results/post_alignment/samtools_index/post_markdup"',
    r'"results/samtools_view"': r'"results/post_alignment/samtools_view"',
    r'"results/tn5_shift"': r'"results/post_alignment/tn5_shift"',
    r'"results/samtools_stats"': r'"results/post_alignment/samtools_stats"',
    r'"results/picard/CollectInsertSizeMetrics"': r'"results/metrics_qc/picard/CollectInsertSizeMetrics"',
    r'"results/picard/CollectAlignmentSummaryMetrics"': r'"results/metrics_qc/picard/CollectAlignmentSummaryMetrics"',
    r'"results/tss_enrichment"': r'"results/metrics_qc/tss_enrichment"',
    r'"results/fragment_size_analysis"': r'"results/metrics_qc/fragment_size_analysis"',
    r'"results/bedtools_genomecov"': r'"results/visualization/bedtools_genomecov"',
    r'"results/sorted_bedgraph_file"': r'"results/visualization/sorted_bedgraph_file"',
    r'"results/bigwig"': r'"results/visualization/bigwig"',
    r'"results/correlation_analysis"': r'"results/visualization/correlation_analysis"',
    r'"results/normalized_coverage"': r'"results/visualization/normalized_coverage"',
    r'"results/heatmap"': r'"results/visualization/heatmap"',
    r'"results/heatmap/plot"': r'"results/visualization/heatmap/plot"',
    r'"results/heatmap/matrix"': r'"results/visualization/heatmap/matrix"',
    r'"results/macs2_peakcall"': r'"results/peak_calling/macs2_peakcall"',
    r'"results/filtered_peaks"': r'"results/peak_calling/filtered_peaks"',
    r'"results/frip_calculation"': r'"results/peak_calling/frip_calculation"',
    r'"results/peak_annotation"': r'"results/peak_calling/peak_annotation"',
    r'"results/preseq"': r'"results/reporting_qc/preseq"',
    r'"results/qualimap"': r'"results/reporting_qc/qualimap"',
    r'"results/qc_gate"': r'"results/qc_gate"',
    r'"results/multiqc"': r'"results/reporting/multiqc"'
}

for filename in ['config.yaml', 'Snakefile']:
    with open(filename, 'r') as f:
        content = f.read()
    
    for old, new in replacements.items():
        content = content.replace(old, new)
        
    # special case for motif_analysis in config
    if filename == 'config.yaml':
        content = content.replace('output: "results"', 'output: "results/peak_calling/motif_analysis"')
        
    with open(filename, 'w') as f:
        f.write(content)

print("Replacement complete.")
