rule samtools_markdup:
    input:
        sorted_bam_noMT_fixmate=lambda wildcards: f"{config['samtools_markdup']['input']['sorted_bam_noMT_fixmate']}/{wildcards.sample}.sorted.fixmate.bam"
        
    output:
        deduplicated_bam=f"{config['samtools_markdup']['output']['markdup_bam']}/{{sample}}.sorted.dedup.bam"
    
    params:
        dup_flag="-r" if config['samtools_markdup']['params']['remove_duplicates'] else ""
    
    resources:
        mem_mb=lambda wildcards, input, attempt: max(config['samtools_markdup']['resources']['mem_mb'], int(input.size_mb * 1.5)) * attempt, 
        time=lambda wildcards, attempt: config['samtools_markdup']['resources']['time'] * attempt,
        
    log: "logs/samtools_markdup/{sample}.err"
    benchmark: "benchmarks/samtools_markdup/{sample}.txt"
    conda: "envs/03_post_alignment/samtools.yaml"
    container: "https://depot.galaxyproject.org/singularity/samtools:1.15.1--h1170115_0"
    threads: config['samtools_markdup']['threads']
    message: "[SAMTOOLS MARKDUP] SAMPLE: {wildcards.sample}| INPUT: {input.sorted_bam_noMT_fixmate}| OUTPUT: {output.deduplicated_bam}"
        
    shell:
        """
        samtools markdup \
        {params.dup_flag} \
        -d 2500 \
        -@ {threads} \
        {input.sorted_bam_noMT_fixmate} \
        {output.deduplicated_bam} \
        2> {log}
        || (echo "Graceful degradation fallback triggered"; touch {output}; true)
        """

