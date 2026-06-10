rule remove_blacklist_reads:
    input:
        bam=lambda wildcards: f"{config['remove_blacklist_reads']['input']['filtered_bam']}/{wildcards.sample}.filtered.pre_blacklist.bam",
        blacklist=config['remove_blacklist_reads']['input']['blacklist']
    output:
        bam=f"{config['remove_blacklist_reads']['output']['filtered_bam_clean']}/{{sample}}.filtered.bam"
    log: "logs/remove_blacklist_reads/{sample}.err"
    benchmark: "benchmarks/remove_blacklist_reads/{sample}.txt"
    conda: "envs/03_post_alignment/bedtools.yaml"
    container: "https://depot.galaxyproject.org/singularity/bedtools:2.30.0--h468198e_3"
    threads: config['remove_blacklist_reads'].get('threads', 2)
    resources:
        mem_mb=config['remove_blacklist_reads']['resources']['mem_mb'],
        time=config['remove_blacklist_reads']['resources']['time']
    message: "[REMOVE BLACKLIST READS] SAMPLE: {wildcards.sample} | Filtering reads using bedtools"
    shell:
        """
        bedtools intersect -v -abam {input.bam} -b {input.blacklist} > {output.bam} 2> {log}
        """
