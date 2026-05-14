
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#>              Modular ATACseq Pipleine                                                                         #>
#>              Author: Himanshu Bhandary          
#>              Mail: 2032ushimanshu@gmail.com                                                              #>
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#restartable: True

import csv
import subprocess
from pathlib import Path

configfile: "config.yaml"

subprocess.run(
    ["python3", "rules/scripts/validate_config.py", "config.yaml"],
    check=True,
)

SAMPLES_TSV = Path(config["global"]["samples"])
with SAMPLES_TSV.open(newline="") as handle:
    rows = list(csv.DictReader(handle, delimiter="\t"))

SAMPLES = [row["sample"] for row in rows]
FASTQ_R1 = {row["sample"]: row["fastq_r1"] for row in rows}
FASTQ_R2 = {row["sample"]: row["fastq_r2"] for row in rows}

if not SAMPLES:
    raise ValueError(f"No samples found in sample sheet: {SAMPLES_TSV}")


# --- Includes ------------------------------------------------------------------
include: "rules/fastp.smk"
include: "rules/fastqc.smk"
include: "rules/bowtie2.smk"
include: "rules/samtools_sort.smk"
include: "rules/calculate_mito_reads.smk"
include: "rules/remove_mito_reads.smk"
include: "rules/samtools_index.smk"
include: "rules/samtools_fixmate.smk"
include: "rules/samtools_markdup.smk"
include: "rules/samtools_view.smk"
include: "rules/samtools_index_post_filter.smk"
include: "rules/tn5_shift.smk"
include: "rules/samtools_stats.smk"
include: "rules/fragment_size_analysis.smk"
include: "rules/picard_alignment_metrics.smk"
include: "rules/picard_insert_size_metrics.smk"
include: "rules/tss_enrichment.smk"
include: "rules/bedtools_genomecov.smk"
include: "rules/sorted_bedgraph.smk"
include: "rules/bigwig.smk"
include: "rules/correlation_analysis.smk"
include: "rules/normalize_coverage.smk"
include: "rules/macs2_peak_calling.smk"
include: "rules/blacklist_filter.smk"
include: "rules/heatmap.smk"
include: "rules/frip_calculation.smk"
include: "rules/peak_annotation.smk"
include: "rules/motif_analysis.smk"
include: "rules/preseq.smk"
include: "rules/qualimap_bamqc.smk"
include: "rules/qc_gate.smk"
include: "rules/multiqc.smk"
# [TEMPLATE] Include your new rule file here so Snakemake can read it.
include: "rules/template_tool.smk"

# --- Targets -------------------------------------------------------------------
QC_GATE_TARGETS = [
    expand("results/qc_gate/{sample}_qc_pass.txt", sample=SAMPLES)
 ]
PREPROCESSING_TARGETS = [
    expand("results/preprocessing/fastp/{sample}_R1_trimmed.fastq.gz", sample=SAMPLES),
    expand("results/preprocessing/fastqc/{sample}_R1_trimmed_fastqc.html", sample=SAMPLES)
]

ALIGNMENT_TARGETS = [
    expand("results/alignment/bowtie2/{sample}.bam", sample=SAMPLES),
    expand("results/post_alignment/samtools_sort/{sample}.sorted.bam", sample=SAMPLES)
]

POST_FILTERING_TARGETS = [
    expand("results/post_alignment/mito-ATAC/{sample}_mito_stats.txt", sample=SAMPLES),
    expand("results/post_alignment/remove_mito_reads/{sample}_noMT.sorted.bam", sample=SAMPLES),
    expand("results/post_alignment/samtools_markdup/{sample}_noMT.sorted.dedup.bam", sample=SAMPLES),
    expand("results/post_alignment/samtools_view/{sample}.filtered.bam", sample=SAMPLES),
    expand("results/post_alignment/tn5_shift/{sample}.filtered.shifted.bam", sample=SAMPLES)
]

QC_METRICS_TARGETS = [
    expand("results/post_alignment/samtools_stats/{sample}_postFiltering.stats.txt", sample=SAMPLES),
    expand("results/metrics_qc/fragment_size_analysis/{sample}_fragment_stats.txt", sample=SAMPLES),
    expand("results/metrics_qc/picard/CollectAlignmentSummaryMetrics/{sample}.alignment_metrics.txt", sample=SAMPLES),
    expand("results/metrics_qc/picard/CollectInsertSizeMetrics/{sample}.insert_metrics.txt", sample=SAMPLES),
    expand("results/metrics_qc/tss_enrichment/{sample}_tss_enrichment.txt", sample=SAMPLES),
    expand("results/reporting_qc/qualimap/{sample}_qualimap_report", sample=SAMPLES),
    expand("results/reporting_qc/preseq/{sample}.ccurve.txt", sample=SAMPLES)
]

VISUALIZATION_TARGETS = [
    expand("results/visualization/bigwig/{sample}.bw", sample=SAMPLES),
    expand("results/visualization/normalized_coverage/{sample}_CPM.bw", sample=SAMPLES),
    "results/visualization/correlation_analysis/correlation_heatmap.png",
    expand("results/visualization/heatmap/plot/{sample}_tss_heatmap.pdf", sample=SAMPLES)
]

PEAK_TARGETS = [
    expand("results/peak_calling/macs2_peakcall/{sample}_peaks.narrowPeak", sample=SAMPLES),
    expand("results/peak_calling/filtered_peaks/{sample}_filtered_peaks.bed", sample=SAMPLES),
    expand("results/peak_calling/frip_calculation/{sample}_frip.txt", sample=SAMPLES),
    expand("results/peak_calling/peak_annotation/{sample}_peak_annotation.txt", sample=SAMPLES),
    expand("results/peak_calling/motif_analysis")
]

# [TEMPLATE] Define the expected final output files of your new tool here.
# Snakemake needs to know what files to create to trigger the rule.
TEMPLATE_TARGETS = [
    expand("results/template_category/template_tool/{sample}_template.txt", sample=SAMPLES)
]

rule all:
    input:
        PREPROCESSING_TARGETS,
        ALIGNMENT_TARGETS,
        POST_FILTERING_TARGETS,
        QC_METRICS_TARGETS,
        VISUALIZATION_TARGETS,
        PEAK_TARGETS,
        QC_GATE_TARGETS,
        "results/reporting/multiqc",
        # [TEMPLATE] Add your target list here so the pipeline explicitly demands those files.
        TEMPLATE_TARGETS
