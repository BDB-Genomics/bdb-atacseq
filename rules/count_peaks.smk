rule count_peaks:
    input:
        consensus=f"{config['consensus_peaks']['output']['consensus']}/consensus_peaks.bed",
        shifted_bam=lambda wildcards: f"{config['count_peaks']['input']['shifted_bam']}/{wildcards.sample}.filtered.shifted.bam"

    output:
        counts=f"{config['count_peaks']['output']}/{{sample}}_peak_counts.tsv"

    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['count_peaks']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt,
        time=lambda wildcards, attempt: config['count_peaks']['resources']['time'] * attempt,

    log: "logs/count_peaks/{sample}.err"
    benchmark: "benchmarks/count_peaks/{sample}.txt"
    conda: "envs/05_peak_calling/consensus.yaml"
    container: "https://depot.galaxyproject.org/singularity/bedtools:2.30.0--h468198e_3"
    threads: config['count_peaks']['threads']
    message: "[Count Peaks] Sample: {wildcards.sample} | Consensus: {input.consensus} | Output: {output.counts}"

    shell:
        """
        bedtools coverage -a {input.consensus} -b {input.shifted_bam} \
            -counts \
        | awk '{{print $1"\\t"$2"\\t"$3"\\t"$NF}}' \
        > {output.counts} \
        2> {log}
        """
