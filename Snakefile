
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#>              Modular ATACseq Framework                                                                        #>
#>              Author: Himanshu Bhandary                                                                        #>
#>              Mail: 2032ushimanshu@gmail.com                                                                   #>
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#restartable: True

import os
import csv
import subprocess
from pathlib import Path

configfile: "config.yaml"

# CI Bypass: Skip validation and provide dummy metadata in GitHub Actions
IS_CI = os.getenv("GITHUB_ACTIONS") == "true"

if not IS_CI:
    try:
        subprocess.run(
            ["python3", "rules/scripts/validate_config.py", "config.yaml"],
            check=True,
        )
    except subprocess.CalledProcessError as e:
        print(f"\n[CRITICAL ERROR] Configuration validation failed for 'config.yaml'.")
        print(f"Please check the validation script output above for specific missing keys or errors.\n")
        raise e

if IS_CI:
    SAMPLES = ["CI_SAMPLE"]
    FASTQ_R1 = {"CI_SAMPLE": "ci_r1.fq.gz"}
    FASTQ_R2 = {"CI_SAMPLE": "ci_r2.fq.gz"}
else:
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
include: "rules/samtools_index_after_markdup.smk"
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
include: "rules/idr.smk"
include: "rules/cross_correlation.smk"
include: "rules/consensus_peaks.smk"
include: "rules/count_peaks.smk"
include: "rules/differential_accessibility.smk"
include: "rules/footprinting.smk"
include: "rules/chromvar_analysis.smk"
include: "rules/benchmark_summary.smk"
include: "rules/multiqc.smk"
# [TEMPLATE] Include your new rule file here so Snakemake can read it.
#include: "rules/template_tool.smk"

# --- Targets -------------------------------------------------------------------
QC_GATE_TARGETS = [
    expand("{path}/{sample}_qc_pass.txt", path=config['qc_gate']['output'], sample=SAMPLES)
 ]
PREPROCESSING_TARGETS = [
    expand("{path}/{sample}_R1_trimmed.fastq.gz", path=config['fastp']['output'], sample=SAMPLES),
    expand("{path}/{sample}_R1_trimmed_fastqc.html", path=config['fastqc']['output'], sample=SAMPLES)
]

ALIGNMENT_TARGETS = [
    expand("{path}/{sample}.bam", path=config['bowtie2']['output'], sample=SAMPLES),
    expand("{path}/{sample}.sorted.bam", path=config['samtools_sort']['output']['sorted_bam'], sample=SAMPLES)
]

POST_FILTERING_TARGETS = [
    expand("{path}/{sample}_mito_stats.txt", path=config['mitoATAC_calculate']['output']['mito_stats'], sample=SAMPLES),
    expand("{path}/{sample}_noMT.sorted.bam", path=config['remove_mito_reads']['output']['noMT_sorted_bam'], sample=SAMPLES),
    expand("{path}/{sample}_noMT.sorted.bam.bai", path=config['samtools_index']['output']['index'], sample=SAMPLES),
    expand("{path}/{sample}_noMT.sorted.dedup.bam", path=config['samtools_markdup']['output']['markdup_bam'], sample=SAMPLES),
    expand("{path}/{sample}_noMT.sorted.dedup.bam.bai", path=config['samtools_index_post_markdup']['output']['index'], sample=SAMPLES),
    expand("{path}/{sample}.filtered.bam", path=config['samtools_view']['output']['filtered_bam'], sample=SAMPLES),
    expand("{path}/{sample}.filtered.shifted.bam", path=config['tn5_shift']['output']['shifted_bam'], sample=SAMPLES)
]

QC_METRICS_TARGETS = [
    expand("{path}/{sample}_postFiltering.stats.txt", path=config['samtools_stats']['output']['stats'], sample=SAMPLES),
    expand("{path}/{sample}_fragment_stats.txt", path=config['fragment_size_analysis']['output'], sample=SAMPLES),
    expand("{path}/{sample}.alignment_metrics.txt", path=config['picard']['alignment_metrics']['output']['alignment_metrics'], sample=SAMPLES),
    expand("{path}/{sample}.insert_metrics.txt", path=config['picard']['insert_metrics']['output']['metrics'], sample=SAMPLES),
    expand("{path}/{sample}_tss_enrichment.txt", path=config['tss_enrichment']['output'], sample=SAMPLES),
    expand("{path}/{sample}_qualimap_report", path=config['qualimap_bamqc']['output']['qc_dir'], sample=SAMPLES),
    expand("{path}/{sample}.ccurve.txt", path=config['preseq']['output']['predicted_complexity'], sample=SAMPLES),
    expand("{path}/{sample}_crosscorr.txt", path=config['cross_correlation']['output'], sample=SAMPLES)
]

VISUALIZATION_TARGETS = [
    expand("{path}/{sample}.bw", path=config['bigwig']['output']['bigwig'], sample=SAMPLES),
    expand("{path}/{sample}_{method}.bw", path=config['normalized_coverage']['output']['normalized_coverage'], method=config['normalized_coverage']['params']['method'], sample=SAMPLES),
    f"{config['correlation_analysis']['output']}/correlation_heatmap.png",
    expand("{path}/{sample}_tss_heatmap.pdf", path=config['heatmap']['output']['plot'], sample=SAMPLES)
]

PEAK_TARGETS = [
    expand("{path}/{sample}_peaks.narrowPeak", path=config['macs2']['output']['peaks'], sample=SAMPLES),
    expand("{path}/{sample}_filtered_peaks.bed", path=config['blacklist_filter']['output']['filtered_peaks'], sample=SAMPLES),
    expand("{path}/{sample}_frip.txt", path=config['frip_calculation']['output'], sample=SAMPLES),
    expand("{path}/{sample}_peak_annotation.txt", path=config['peak_annotation']['output'], sample=SAMPLES),
    expand("{path}/{sample}", path=config['motif_analysis']['output'], sample=SAMPLES),
    config['consensus_peaks']['output']['consensus'] + "/consensus_peaks.bed",
    config['consensus_peaks']['output']['counts'] + "/peak_sample_counts.txt",
    config['differential_accessibility']['output']['results'] + "/diff_accessibility_results.tsv",
    config['differential_accessibility']['output']['plots'] + "/volcano_plot.pdf",
    config['differential_accessibility']['output']['plots'] + "/ma_plot.pdf",
    config['differential_accessibility']['output']['plots'] + "/pca_plot.pdf",
    expand("{path}/{sample}_footprints.bed", path=config['footprinting']['output']['footprints'], sample=SAMPLES),
    expand("{path}/{sample}_deviations.tsv", path=config['chromvar_analysis']['output']['deviations'], sample=SAMPLES),
    config['benchmark_summary']['output']
]

# [TEMPLATE] Define the expected final output files of your new tool here.
# Snakemake needs to know what files to create to trigger the rule.
#TEMPLATE_TARGETS = [
#    expand("results/template_category/template_tool/{sample}_template.txt", sample=SAMPLES)
#]

rule all:
    input:
        PREPROCESSING_TARGETS,
        ALIGNMENT_TARGETS,
        POST_FILTERING_TARGETS,
        QC_METRICS_TARGETS,
        QC_GATE_TARGETS,
        VISUALIZATION_TARGETS,
        PEAK_TARGETS,
        directory(config['multiqc']['output']),
        # [TEMPLATE] Add your target list here so the pipeline explicitly demands those files.
        #TEMPLATE_TARGETS


# --- Lifecycle Hooks -----------------------------------------------------------

onstart:
    print(f"\n[START] BDB-Genomics ATAC-seq Framework")
    print(f"Samples: {len(SAMPLES)} samples detected\n")

onsuccess:
    print(f"\n[SUCCESS] Pipeline completed successfully!")
    print(f"Final MultiQC report: {config['multiqc']['output']}/multiqc_report.html\n")

onerror:
    print(f"\n[ERROR] Pipeline encountered an error.")
    print(f"Please check the log files in 'logs/' for details.\n")
