rule samtools_index_post_filter:
    input:
        filtered_bam=lambda wildcards: f"{config['samtools_index_post_filter']['input']['filtered_bam']}/{wildcards.sample}.filtered.bam"
        
    output:
        filtered_bam_indexed=f"{config['samtools_index_post_filter']['output']['filtered_bam_indexed']}/{{sample}}.filtered.bam.bai"
    
    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['samtools_index_post_filter']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt, 
        time=lambda wildcards, attempt: config['samtools_index_post_filter']['resources']['time'] * attempt,

    log: "logs/samtools_index_post_filter/{sample}.out"
    benchmark: "benchmarks/samtools_index_post_filter/{sample}.txt"
    conda: "envs/03_post_alignment/samtools.yaml" if config.get("use_conda", True) else None
    container: "docker://quay.io/biocontainers/samtools:1.15.1--h1170115_0" if config.get("use_container", True) else None
    threads: config['samtools_index_post_filter']['threads']
    message: "[SAMTOOLS INDEX POST FILTER] SAMPLE: {wildcards.sample}| INPUT: {input.filtered_bam}| OUTPUT: {output.filtered_bam_indexed}"
        
    shell:
        """
        samtools index \
        -@ {threads} \
        {input.filtered_bam} \
        {output.filtered_bam_indexed} \
        2> {log}
        """
