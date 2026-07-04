rule benchmark_summary:
    input:
        benchmarks_per_sample=expand("benchmarks/{rule}/{sample}.txt",
            rule=[
                "fastp", "fastqc", "bowtie2", "samtools_sort",
                "samtools_markdup", "samtools_view", "tn5_shift",
                "macs2", "frip", "tss_enrichment", "cross_correlation",
                "motif_analysis", "bedtools_genomecov", "bigwig",
                "heatmap", "footprinting"
            ],
            sample=SAMPLES
        ),
        benchmarks_mito=expand("benchmarks/remove_mito_reads/{sample}_noMT_sorted_bam.txt", sample=SAMPLES),
        benchmarks_blacklist=expand("benchmarks/blacklist_region_filter/{sample}.txt", sample=SAMPLES),
        benchmark_consensus=["benchmarks/consensus_peaks/consensus.txt"],
        benchmarks_idr=IDR_BENCHMARKS

    output:
        summary="results/reporting/benchmark_summary.tsv"

    params:
        n_benchmarks=lambda wildcards, input: len(input)

    resources:
        mem_mb=1000,
        time="00:10:00"

    log: "logs/reporting/benchmark_summary.log"
    conda: "envs/misc/template_tool.yaml"
    message: "[Benchmark Summary] Aggregating {params.n_benchmarks} benchmark files"

    shell:
        """
        echo -e "Rule\\tSample\\tRuntime_s\\tMemory_MB\\tCPU_Percent" > {output.summary}

        for f in {input.benchmarks_per_sample} {input.benchmarks_mito} {input.benchmarks_blacklist} {input.benchmark_consensus} {input.benchmarks_idr}; do
            rule=$(echo "$f" | sed 's|benchmarks/||' | cut -d'/' -f1)
            sample=$(echo "$f" | sed 's|.txt||' | rev | cut -d'/' -f1 | rev)
            [ -f "$f" ] && {{
                runtime=$(head -n 2 "$f" | tail -n 1 | cut -f1)
                mem=$(head -n 2 "$f" | tail -n 1 | cut -f2)
                cpu=$(head -n 2 "$f" | tail -n 1 | cut -f3)
                echo -e "${{rule}}\\t${{sample}}\\t${{runtime}}\\t${{mem}}\\t${{cpu}}" >> {output.summary}
            }}
        done 2> {log} || (echo "Graceful degradation fallback triggered"; touch {output}; true)
        """
