rule benchmark_summary:
    input:
        benchmarks=expand("benchmarks/{rule}/{sample}.txt",
            rule=[
                "fastp", "fastqc", "bowtie2", "samtools_sort",
                "samtools_markdup", "samtools_view", "tn5_shift",
                "macs2", "frip", "tss_enrichment", "cross_correlation",
                "bedtools_genomecov", "bigwig", "heatmap"
            ],
            sample=SAMPLES
        )

    output:
        summary="results/reporting/benchmark_summary.tsv"

    resources:
        mem_mb=1000,
        time="00:10:00"

    conda: "envs/misc/template_tool.yaml"
    message: "[Benchmark Summary] Aggregating {len(input.benchmarks)} benchmark files"

    shell:
        """
        echo -e "Rule\\tSample\\tRuntime_s\\tMemory_MB\\tCPU_Percent" > {output.summary}

        for f in {input.benchmarks}; do
            rule=$(echo "$f" | sed 's|benchmarks/||' | cut -d'/' -f1)
            sample=$(echo "$f" | sed 's|.txt||' | rev | cut -d'/' -f1 | rev)
            if [ -f "$f" ]; then
                runtime=$(head -1 "$f" | cut -f1)
                mem=$(head -1 "$f" | cut -f2)
                cpu=$(head -1 "$f" | cut -f3)
                echo -e "${{rule}}\\t${{sample}}\\t${{runtime}}\\t${{mem}}\\t${{cpu}}" >> {output.summary}
            fi
        done
        """
