rule blacklist_region_filter:
    input:
        peaks=lambda wildcards: f"{config['blacklist_filter']['input']['peaks']}/{wildcards.sample}_peaks.narrowPeak"

    output:
        filtered_peaks=f"{config['blacklist_filter']['output']['filtered_peaks']}/{{sample}}_filtered_peaks.bed"

    params:
        blacklist=config['blacklist_filter']['params']['blacklist']

    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['blacklist_filter']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt,
        time=lambda wildcards, attempt: config['blacklist_filter']['resources']['time'] * attempt,

    log: "logs/blacklist_region_filter/{sample}.err"
    benchmark: "benchmarks/blacklist_region_filter/{sample}.txt"
    conda: "envs/03_post_alignment/bedtools.yaml"
    container: "https://depot.galaxyproject.org/singularity/bedtools:2.30.0--h468198e_3"
    threads: config['blacklist_filter']['threads']
    message: "[Bedtools intersect] Sample: {wildcards.sample} | Peaks: {input.peaks} | Filtered Peaks: {output.filtered_peaks} | Blacklist: {params.blacklist}"

    shell:
        """
        bedtools intersect -v \
            -a {input.peaks} \
            -b {params.blacklist} \
        > {output.filtered_peaks} \
        2> {log}
        """
