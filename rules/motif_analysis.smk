rule motif_analysis:
    input:
        filtered_peaks=lambda wildcards: f"{config['blacklist_filter']['output']['filtered_peaks']}/{wildcards.sample}_filtered_peaks.bed",
        qc_pass=lambda wildcards: f"{config['qc_gate']['output']}/{wildcards.sample}_qc_pass.txt"

    output:
        html=directory(f"{config['motif_analysis']['output']}/{{sample}}")

    params:
        motif_db=config['motif_analysis']['params']['motif_db'],
        genome_assembly=config['motif_analysis']['params']['genome_assembly']

    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['motif_analysis']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt,
        time=lambda wildcards, attempt: config['motif_analysis']['resources']['time'] * attempt,

    log: "logs/motif_analysis/{sample}.log"
    benchmark: "benchmarks/motif_analysis/{sample}.txt"
    conda: "envs/05_peak_calling/motif_analysis.yaml"
    container: "docker://quay.io/biocontainers/homer:4.11--pl526hc9558a2_3"
    threads: config['motif_analysis']['threads']
    message: "[Motif analysis] Sample: {wildcards.sample} | Peaks: {input.filtered_peaks} | Output: {output.html}"

    shell:
        """
        status=$(awk '{{print $2}}' {input.qc_pass})
        if [ "$status" = "PASSED" ]; then
            if [ ! -s {input.filtered_peaks} ]; then
                echo "Peak file is empty. Generating empty/placeholder motif directory." > {log}
                mkdir -p {output.html}
            else
                findMotifsGenome.pl {input.filtered_peaks} {params.genome_assembly} {output.html} \
                    -p {threads} \
                    -len 8,10,12 \
                    -size 200 \
                2> {log}
            fi
        else
            echo "QC FAILED for {wildcards.sample}. Generating empty/placeholder motif directory." > {log}
            mkdir -p {output.html}
        fi
        """

